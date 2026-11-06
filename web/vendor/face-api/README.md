# Bundled face-api.js

Upstream: https://github.com/justadudewhohacks/face-api.js
Version: 0.22.2
Revision: 8609b25a15f417398a4d2b95dc91985cd1e0c0c3
License: MIT (see LICENSE).

Runtime: dist/face-api.min.js. Model files copied unchanged from weights/:
tiny_face_detector, face_landmark_68_tiny, face_recognition, face_expression.
The face_expression model (same 0.22.2 release, weights/ directory) supplies the
smile score for the photo pose gate. No age or gender models are loaded.

The application serves these files from its own origin. Photo processing and
descriptor comparison run locally; there is no recognition API or CDN request.
