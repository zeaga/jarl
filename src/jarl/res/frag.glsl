#version 330 core

in vec2 uv;
out vec4 fragColor;

void main() {
    fragColor = vec4((uv + 1.0) * 0.5, 0.0, 1.0);
}