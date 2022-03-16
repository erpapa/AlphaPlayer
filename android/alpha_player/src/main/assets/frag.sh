#extension GL_OES_EGL_image_external : require
precision mediump float;
varying vec2 vTextureCoord;
uniform samplerExternalOES sTexture;

void main() {
    vec4 color = texture2D(sTexture, vec2(vTextureCoord.x * 0.5, vTextureCoord.y));
    vec4 colorMap = texture2D(sTexture, vec2(vTextureCoord.x * 0.5 + 0.5, vTextureCoord.y));
    gl_FragColor = vec4(color.r, color.g, color.b, colorMap.g);
}