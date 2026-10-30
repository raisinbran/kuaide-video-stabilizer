#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]
//! WP 1B.1 spike: plays one local video through a custom protocol and through
//! a loopback HTTP server, so later work can measure both delivery methods.

mod range;

use std::collections::hash_map::RandomState;
use std::hash::{BuildHasher, Hasher};
use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use std::time::{SystemTime, UNIX_EPOCH};

use serde::Serialize;
use tauri::http::{header, Request, Response, StatusCode};
use tauri::State;

/// The custom protocol answers from memory, so keep each reply small.
const PROTOCOL_CHUNK: u64 = 4 * 1024 * 1024;
const HTTP_CHUNK: u64 = 8 * 1024 * 1024;

/// The one file the window may play, and the token both URLs must carry.
#[derive(Default)]
struct Opened {
    path: Option<PathBuf>,
    token: String,
}

type Shared = Arc<Mutex<Opened>>;

struct AppState {
    opened: Shared,
    http_port: u16,
}

#[derive(Serialize)]
struct VideoUrls {
    protocol: String,
    http: String,
    size_bytes: u64,
}

/// A random hex token; only needs to be unguessable by other local web pages.
fn new_token() -> String {
    let mut hasher = RandomState::new().build_hasher();
    hasher.write_u128(SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_nanos());
    format!("{:016x}", hasher.finish())
}

fn lookup(opened: &Shared, token: &str) -> Option<PathBuf> {
    let opened = opened.lock().ok()?;
    match &opened.path {
        Some(path) if !token.is_empty() && token == opened.token => Some(path.clone()),
        _ => None,
    }
}

#[tauri::command]
fn open_video(path: String, state: State<AppState>) -> Result<VideoUrls, String> {
    let path = PathBuf::from(path);
    let meta = std::fs::metadata(&path).map_err(|e| format!("cannot open {}: {e}", path.display()))?;
    if !meta.is_file() {
        return Err(format!("not a file: {}", path.display()));
    }
    let token = new_token();
    *state.opened.lock().map_err(|e| e.to_string())? = Opened { path: Some(path), token: token.clone() };
    // WebView2 on Windows exposes custom protocols as http://<name>.localhost.
    let protocol = if cfg!(windows) {
        format!("http://media.localhost/{token}")
    } else {
        format!("media://localhost/{token}")
    };
    Ok(VideoUrls { protocol, http: format!("http://127.0.0.1:{}/{token}", state.http_port), size_bytes: meta.len() })
}

#[tauri::command]
fn self_test_video() -> Option<String> {
    std::env::var("KUAIDE_SELFTEST_VIDEO").ok()
}

/// Writes the self-test report to a new file and closes the app with 0 (passed) or 1.
#[tauri::command]
fn finish_self_test(report: serde_json::Value, passed: bool, app: tauri::AppHandle) -> Result<(), String> {
    let path = std::env::var("KUAIDE_SELFTEST_REPORT").map_err(|_| "KUAIDE_SELFTEST_REPORT is not set".to_string())?;
    let file = std::fs::OpenOptions::new().write(true).create_new(true).open(&path).map_err(|e| e.to_string())?;
    serde_json::to_writer_pretty(file, &report).map_err(|e| e.to_string())?;
    app.exit(if passed { 0 } else { 1 });
    Ok(())
}

/// Ends a self-test that could not write its report, with exit code 2.
#[tauri::command]
fn abort_self_test(app: tauri::AppHandle) {
    app.exit(2);
}

fn protocol_response(opened: &Shared, request: &Request<Vec<u8>>) -> Response<Vec<u8>> {
    let token = request.uri().path().trim_start_matches('/');
    let Some(path) = lookup(opened, token) else {
        return status_only(StatusCode::NOT_FOUND, None);
    };
    let range = request.headers().get(header::RANGE).and_then(|v| v.to_str().ok());
    match range::read_part(&path, range, PROTOCOL_CHUNK) {
        Ok(part) => {
            let mut builder = Response::builder()
                .status(part.status)
                .header(header::CONTENT_TYPE, range::content_type(&path))
                .header(header::ACCEPT_RANGES, "bytes")
                .header(header::CONTENT_LENGTH, part.body.len());
            if part.status == 206 {
                builder = builder.header(header::CONTENT_RANGE, part.content_range());
            }
            builder.body(part.body).unwrap_or_else(|_| status_only(StatusCode::INTERNAL_SERVER_ERROR, None))
        }
        Err(range::PartError::Unsatisfiable { total }) => {
            status_only(StatusCode::RANGE_NOT_SATISFIABLE, Some(format!("bytes */{total}")))
        }
        Err(range::PartError::Io) => status_only(StatusCode::INTERNAL_SERVER_ERROR, None),
    }
}

fn status_only(status: StatusCode, content_range: Option<String>) -> Response<Vec<u8>> {
    let mut builder = Response::builder().status(status);
    if let Some(value) = content_range {
        builder = builder.header(header::CONTENT_RANGE, value);
    }
    builder.body(Vec::new()).expect("static response parts are valid")
}

/// Serves the opened file on 127.0.0.1 with range support, one thread per request.
fn start_http_server(opened: Shared) -> std::io::Result<u16> {
    let server = tiny_http::Server::http("127.0.0.1:0").map_err(std::io::Error::other)?;
    let port = server.server_addr().to_ip().map(|a| a.port()).ok_or_else(|| std::io::Error::other("no IP address"))?;
    std::thread::spawn(move || {
        for request in server.incoming_requests() {
            let opened = opened.clone();
            std::thread::spawn(move || {
                let reply = http_reply(&opened, &request);
                let _ = request.respond(reply);
            });
        }
    });
    Ok(port)
}

fn http_reply(opened: &Shared, request: &tiny_http::Request) -> tiny_http::Response<std::io::Cursor<Vec<u8>>> {
    let empty = |code: u16| tiny_http::Response::from_data(Vec::new()).with_status_code(code);
    let token = request.url().trim_start_matches('/');
    let Some(path) = lookup(opened, token) else { return empty(404) };
    let range = request.headers().iter().find(|h| h.field.equiv("Range")).map(|h| h.value.as_str());
    match range::read_part(&path, range, HTTP_CHUNK) {
        Ok(part) => {
            let mut reply = tiny_http::Response::from_data(Vec::new()).with_status_code(part.status);
            reply.add_header(text_header("Content-Type", range::content_type(&path)));
            reply.add_header(text_header("Accept-Ranges", "bytes"));
            if part.status == 206 {
                reply.add_header(text_header("Content-Range", &part.content_range()));
            }
            let len = part.body.len();
            reply.with_data(std::io::Cursor::new(part.body), Some(len))
        }
        Err(range::PartError::Unsatisfiable { total }) => {
            let mut reply = empty(416);
            reply.add_header(text_header("Content-Range", &format!("bytes */{total}")));
            reply
        }
        Err(range::PartError::Io) => empty(500),
    }
}

fn text_header(name: &str, value: &str) -> tiny_http::Header {
    tiny_http::Header::from_bytes(name.as_bytes(), value.as_bytes()).expect("ASCII header")
}

fn main() {
    if std::env::var_os("KUAIDE_SELFTEST_VIDEO").is_some() {
        // A stuck page must still end the self-test, so callers see a failure, not a hang.
        std::thread::spawn(|| {
            std::thread::sleep(std::time::Duration::from_secs(120));
            std::process::exit(3);
        });
    }
    let opened: Shared = Arc::default();
    let http_port = start_http_server(opened.clone()).expect("loopback HTTP server could not start");
    let protocol_state = opened.clone();
    tauri::Builder::default()
        .manage(AppState { opened, http_port })
        .register_asynchronous_uri_scheme_protocol("media", move |_ctx, request, responder| {
            let opened = protocol_state.clone();
            std::thread::spawn(move || responder.respond(protocol_response(&opened, &request)));
        })
        .invoke_handler(tauri::generate_handler![open_video, self_test_video, finish_self_test, abort_self_test])
        .run(tauri::generate_context!())
        .expect("error while running the preview spike");
}
