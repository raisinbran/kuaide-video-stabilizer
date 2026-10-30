// Plays one local video by either delivery method. With KUAIDE_SELFTEST_VIDEO
// set, it plays and seeks by both methods, reports, and closes the app.
const { invoke } = window.__TAURI__.core;
const video = document.getElementById('video');
const log = (line) => { document.getElementById('log').textContent += line + '\n'; };

// Resolves on `name`, rejects on a media error or after `ms`.
function waitEvent(name, ms) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => done(reject, new Error(`timeout waiting for ${name}`)), ms);
    const onEvent = () => done(resolve);
    const onError = () => done(reject, new Error(`media error ${video.error ? video.error.code : '?'}`));
    function done(settle, value) {
      clearTimeout(timer);
      video.removeEventListener(name, onEvent);
      video.removeEventListener('error', onError);
      settle(value);
    }
    video.addEventListener(name, onEvent);
    video.addEventListener('error', onError);
  });
}

async function waitUntil(test, ms) {
  const end = performance.now() + ms;
  while (!test()) {
    if (performance.now() > end) throw new Error('timeout waiting for playback to advance');
    await new Promise((r) => setTimeout(r, 50));
  }
}

// Plays from the start to 1 s, then seeks to the middle; returns timings.
async function playAndSeek(method, url) {
  const started = performance.now();
  video.src = url;
  await waitEvent('loadedmetadata', 15000);
  await video.play();
  await waitUntil(() => video.currentTime >= 1.0, 15000);
  const reachedOneSecond = performance.now();
  video.currentTime = video.duration / 2;
  await waitEvent('seeked', 15000);
  const result = {
    method, ok: true, width: video.videoWidth, height: video.videoHeight, duration_s: video.duration,
    start_to_one_second_ms: Math.round(reachedOneSecond - started),
    seek_ms: Math.round(performance.now() - reachedOneSecond),
  };
  video.pause();
  return result;
}

async function open(method) {
  const urls = await invoke('open_video', { path: document.getElementById('path').value });
  log(`${method}: ${urls[method]} (${urls.size_bytes} bytes)`);
  return urls[method];
}

for (const method of ['protocol', 'http']) {
  document.getElementById(method).addEventListener('click', async () => {
    try { log(JSON.stringify(await playAndSeek(method, await open(method)))); } catch (e) { log(`${method}: ${e}`); }
  });
}

(async () => {
  const path = await invoke('self_test_video');
  if (!path) return;
  document.getElementById('path').value = path;
  const results = [];
  for (const method of ['protocol', 'http']) {
    try { results.push(await playAndSeek(method, await open(method))); }
    catch (e) { results.push({ method, ok: false, error: String(e) }); }
  }
  const passed = results.every((r) => r.ok);
  await invoke('finish_self_test', { report: { passed, video: path, results }, passed });
})();
