uniform mat4 uMVPMatrix;
uniform mat4 uSTMatrix;

attribute vec3 aPosition;
attribute vec2 aTextureCoord;

varying vec2 vTextureCoord;

void main() {
    gl_Position = uMVPMatrix * vec4(aPosition, 1.0);
    vTextureCoord = (uSTMatrix * vec4(aTextureCoord, 0.0, 1.0)).xy;
}