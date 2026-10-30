//! Byte-range reads shared by both video delivery methods.

use std::fs::File;
use std::io::{Read, Seek, SeekFrom};
use std::path::Path;

/// One HTTP response body cut from a file.
#[derive(Debug, PartialEq)]
pub struct Part {
    pub status: u16,
    pub start: u64,
    pub total: u64,
    pub body: Vec<u8>,
}

#[derive(Debug)]
pub enum PartError {
    /// The requested range starts at or past the end of the file (HTTP 416).
    Unsatisfiable { total: u64 },
    /// The file could not be opened or read; the reply is a plain 500.
    Io,
}

/// Parses one `bytes=` range into inclusive offsets.
///
/// A missing, malformed or multi-range header returns `None`, which callers
/// treat as "no range", as RFC 9110 allows.
fn parse(header: Option<&str>, total: u64) -> Result<Option<(u64, u64)>, PartError> {
    let Some(spec) = header.and_then(|h| h.trim().strip_prefix("bytes=")) else {
        return Ok(None);
    };
    if spec.contains(',') {
        return Ok(None);
    }
    let Some((first, last)) = spec.split_once('-') else {
        return Ok(None);
    };
    let (first, last) = (first.trim(), last.trim());
    let range = if first.is_empty() {
        // Suffix form `bytes=-N`: the last N bytes.
        let Ok(n) = last.parse::<u64>() else { return Ok(None) };
        if n == 0 || total == 0 {
            return Err(PartError::Unsatisfiable { total });
        }
        (total.saturating_sub(n), total - 1)
    } else {
        let Ok(start) = first.parse::<u64>() else { return Ok(None) };
        let end = if last.is_empty() {
            u64::MAX
        } else {
            match last.parse::<u64>() {
                Ok(end) if end >= start => end,
                _ => return Ok(None),
            }
        };
        if start >= total {
            return Err(PartError::Unsatisfiable { total });
        }
        (start, end.min(total - 1))
    };
    Ok(Some(range))
}

/// Reads the part of `path` that a request with `range_header` should get.
///
/// No body is longer than `max_chunk` bytes; the player asks again for the rest.
/// A request without a range gets the whole file (200) when it fits, and
/// otherwise the first chunk as a 206. RFC 9110 does not allow a 206 for an
/// unranged request, but Chromium always sends a range for media.
pub fn read_part(path: &Path, range_header: Option<&str>, max_chunk: u64) -> Result<Part, PartError> {
    let mut file = File::open(path).map_err(|_| PartError::Io)?;
    let total = file.metadata().map_err(|_| PartError::Io)?.len();
    let (status, start, end) = match parse(range_header, total)? {
        Some((start, end)) => (206, start, end.min(start.saturating_add(max_chunk - 1))),
        None if total == 0 => return Ok(Part { status: 200, start: 0, total, body: Vec::new() }),
        None if total <= max_chunk => (200, 0, total - 1),
        None => (206, 0, max_chunk - 1),
    };
    let mut body = vec![0; (end - start + 1) as usize];
    file.seek(SeekFrom::Start(start)).map_err(|_| PartError::Io)?;
    file.read_exact(&mut body).map_err(|_| PartError::Io)?;
    Ok(Part { status, start, total, body })
}

impl Part {
    /// The `Content-Range` value for a 206 response.
    pub fn content_range(&self) -> String {
        let end = self.start + self.body.len() as u64 - 1;
        format!("bytes {}-{}/{}", self.start, end, self.total)
    }
}

/// Picks a video MIME type from the file extension.
pub fn content_type(path: &Path) -> &'static str {
    match path.extension().and_then(|e| e.to_str()).map(str::to_ascii_lowercase).as_deref() {
        Some("webm") => "video/webm",
        Some("mov") => "video/quicktime",
        _ => "video/mp4",
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// A temporary file of known bytes, deleted when the test ends.
    struct Sample {
        path: std::path::PathBuf,
        bytes: Vec<u8>,
    }

    impl Drop for Sample {
        fn drop(&mut self) {
            let _ = std::fs::remove_file(&self.path);
        }
    }

    fn sample(len: usize) -> Sample {
        let bytes: Vec<u8> = (0..len).map(|i| (i % 251) as u8).collect();
        let path = std::env::temp_dir().join(format!("kuaide-range-{}-{len}.bin", std::process::id()));
        std::fs::write(&path, &bytes).unwrap();
        Sample { path, bytes }
    }

    #[test]
    fn closed_range_returns_exact_bytes() {
        let s = sample(1000);
        let part = read_part(&s.path, Some("bytes=10-19"), 4096).unwrap();
        assert_eq!(part.status, 206);
        assert_eq!(part.body, s.bytes[10..20]);
        assert_eq!(part.content_range(), "bytes 10-19/1000");
    }

    #[test]
    fn closed_range_past_end_is_trimmed_to_file_end() {
        let s = sample(1001);
        let part = read_part(&s.path, Some("bytes=990-5000"), 4096).unwrap();
        assert_eq!(part.body, s.bytes[990..]);
        assert_eq!(part.content_range(), "bytes 990-1000/1001");
    }

    #[test]
    fn open_range_is_capped_at_chunk_size() {
        let s = sample(1002);
        let part = read_part(&s.path, Some("bytes=100-"), 64).unwrap();
        assert_eq!(part.body, s.bytes[100..164]);
        assert_eq!(part.content_range(), "bytes 100-163/1002");
    }

    #[test]
    fn suffix_range_returns_file_end_or_whole_file() {
        let s = sample(1003);
        assert_eq!(read_part(&s.path, Some("bytes=-5"), 4096).unwrap().body, s.bytes[998..]);
        assert_eq!(read_part(&s.path, Some("bytes=-5000"), 4096).unwrap().body, s.bytes);
        assert!(matches!(read_part(&s.path, Some("bytes=-0"), 4096), Err(PartError::Unsatisfiable { .. })));
    }

    #[test]
    fn missing_range_returns_whole_small_file_or_first_chunk() {
        let s = sample(1004);
        let whole = read_part(&s.path, None, 4096).unwrap();
        assert_eq!((whole.status, whole.body.as_slice()), (200, s.bytes.as_slice()));
        let first = read_part(&s.path, None, 100).unwrap();
        assert_eq!((first.status, first.body.as_slice()), (206, &s.bytes[..100]));
        assert_eq!(first.content_range(), "bytes 0-99/1004");
    }

    #[test]
    fn range_past_end_is_unsatisfiable() {
        let s = sample(1005);
        assert!(matches!(
            read_part(&s.path, Some("bytes=1005-"), 4096),
            Err(PartError::Unsatisfiable { total: 1005 })
        ));
    }

    #[test]
    fn empty_file_is_whole_without_range_and_unsatisfiable_with_one() {
        let s = sample(0);
        assert_eq!(read_part(&s.path, None, 4096).unwrap(), Part { status: 200, start: 0, total: 0, body: Vec::new() });
        assert!(matches!(read_part(&s.path, Some("bytes=0-"), 4096), Err(PartError::Unsatisfiable { total: 0 })));
    }

    #[test]
    fn malformed_range_is_ignored() {
        let s = sample(1006);
        assert_eq!(read_part(&s.path, Some("bytes=9-3"), 4096).unwrap().status, 200);
        assert_eq!(read_part(&s.path, Some("items=0-3"), 4096).unwrap().status, 200);
    }
}