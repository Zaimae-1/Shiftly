'use strict';
// Local-only face-api.js 0.22.2. No photos or descriptors leave this origin.
window.HadirFaces = (() => {
  let loading;
  let database;
  const base = new URL('vendor/face-api/', document.baseURI);
  function loadScript() {
    if (window.faceapi) return Promise.resolve();
    return new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = new URL('face-api.min.js', base).href;
      script.onload = resolve;
      script.onerror = () => { script.remove(); reject(new Error('Model runtime unavailable')); };
      document.head.appendChild(script);
    });
  }
  function prepare() {
    if (!loading) {
      loading = (async () => {
        await loadScript();
        const models = new URL('models/', base).href;
        await Promise.all([
          faceapi.nets.tinyFaceDetector.loadFromUri(models),
          faceapi.nets.faceLandmark68TinyNet.loadFromUri(models),
          faceapi.nets.faceRecognitionNet.loadFromUri(models),
          faceapi.nets.faceExpressionNet.loadFromUri(models),
        ]);
      })().catch(error => { loading = null; throw error; });
    }
    return loading;
  }
  async function extract(photo) {
    await prepare();
    const image = new Image();
    image.src = 'data:image/jpeg;base64,' + photo;
    await image.decode();
    const canvas = document.createElement('canvas');
    const ratio = Math.min(1, 640 / Math.max(image.naturalWidth, image.naturalHeight));
    canvas.width = Math.max(1, Math.round(image.naturalWidth * ratio));
    canvas.height = Math.max(1, Math.round(image.naturalHeight * ratio));
    canvas.getContext('2d').drawImage(image, 0, 0, canvas.width, canvas.height);
    const faces = await faceapi.detectAllFaces(canvas,
      new faceapi.TinyFaceDetectorOptions({inputSize: 320, scoreThreshold: .55}))
      .withFaceLandmarks(true).withFaceDescriptors().withFaceExpressions();
    if (faces.length === 0) return JSON.stringify({status:'noFace'});
    if (faces.length !== 1) return JSON.stringify({status:'multiple'});
    const face = faces[0];
    if (face.detection.box.width < 64 || face.detection.box.height < 64 || face.detection.score < .65)
      return JSON.stringify({status:'unclear'});
    const p = face.landmarks.positions;
    const mean = points => ({x: points.reduce((s,v)=>s+v.x,0)/points.length,
      y: points.reduce((s,v)=>s+v.y,0)/points.length});
    const left = mean(p.slice(36,42)), right = mean(p.slice(42,48));
    const distance = (a,b) => Math.hypot(a.x-b.x,a.y-b.y);
    const eyeDistance = distance(left,right);
    const eyeMid = mean([left,right]), mouthMid = mean([p[48],p[54]]);
    const ear = start => (distance(p[start+1],p[start+5])+distance(p[start+2],p[start+4])) /
      (2*distance(p[start],p[start+3]));
    // Conservative landmark-based head alignment, not iris/eye-gaze tracking.
    // All coordinates belong to the exact frame whose descriptor is matched.
    const noseRatio = (p[30].y-eyeMid.y)/(mouthMid.y-eyeMid.y);
    const facingCamera = eyeDistance > 0 &&
      Math.abs(left.y-right.y)/eyeDistance < .18 &&
      Math.abs(p[30].x-eyeMid.x)/eyeDistance < .18 &&
      noseRatio > .35 && noseRatio < .85 &&
      ear(36) > .17 && ear(42) > .17;
    return JSON.stringify({status:'face', descriptor:Array.from(face.descriptor),
      smiling: (face.expressions.happy ?? 0) >= .7, facingCamera});
  }
  function openDatabase() {
    if (!database) database = new Promise((resolve, reject) => {
      const request = indexedDB.open('hadir-students', 1);
      request.onupgradeneeded = () => request.result.createObjectStore('settings');
      request.onerror = () => reject(request.error);
      request.onsuccess = () => resolve(request.result);
    }).catch(error => { database = null; throw error; });
    return database;
  }
  async function loadData(key) {
    const db = await openDatabase();
    return new Promise((resolve, reject) => {
      const request = db.transaction('settings', 'readonly').objectStore('settings').get(key);
      request.onsuccess = () => resolve(request.result ?? 'null');
      request.onerror = () => reject(request.error);
    });
  }
  async function saveData(key, data) {
    JSON.parse(data);
    const db = await openDatabase();
    return new Promise((resolve, reject) => {
      const tx = db.transaction('settings', 'readwrite');
      tx.objectStore('settings').put(data, key);
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error);
      tx.onabort = () => reject(tx.error || new Error('Penyimpanan dibatalkan'));
    });
  }
  return {prepare, extract,
    loadStudents: () => loadData('students'),
    saveStudents: data => saveData('students', data),
    loadAttendance: () => loadData('attendance'),
    saveAttendance: data => saveData('attendance', data),
  };
})();
