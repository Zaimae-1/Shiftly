# MobileFaceNet — native Android/iOS only

Bundled export: `mobilefacenet.tflite` (5,233,552 bytes).

Source: https://github.com/MCarlomagno/FaceRecognitionAuth/blob/db9c605aa52792708e09fd8d973ed5d03ef4f506/assets/mobilefacenet.tflite

Revision: `db9c605aa52792708e09fd8d973ed5d03ef4f506`.
SHA-256: `be4bc7cfc53f7bc336d0f28b1ab92535f618c913a422b683210750f6b5354854`.
The source repository's BSD-3-Clause license is retained in
`LICENSE.mobilefacenet.txt`. Upstream describes this as MobileFaceNet; this is
a pretrained third-party export, not a model trained by this app.

Verified with the LiteRT interpreter: float32 RGB input `[1,112,112,3]`,
float32 output `[1,192]`, finite L2-normalized output. Preprocessing follows
the export's `(channel - 128) / 128` convention. The app first bakes EXIF
orientation, detects a single frontal face with ML Kit, aligns five landmarks
to the 112px template, then infers and L2-normalizes the descriptor.

Model/preprocessing ID: `mobilefacenet-192-be4bc7cf-aligned-v1`.
Starting Euclidean threshold: 0.65, nearest/runner-up margin: 0.10.
These are provisional parameters, not a claimed accuracy rate. Validate on
different students, lighting, poses and unknown faces before operational use.
This pipeline does not implement liveness or spoof prevention.

Do not replace this file with a different export without rechecking tensor
shapes, normalization, threshold and the model/preprocessing ID, and rebuilding
enrollments. The 192-D mobile descriptors are incompatible with the existing
128-D face-api.js web descriptors. Web recognition and its database remain
separate and unchanged.
