shader_type canvas_item;

void fragment() {
    // Take the alpha of the original pixel
    float a = texture(TEXTURE, UV).a * COLOR.a;
    // Force RGB to white, keep the alpha
    COLOR = vec4(1.0, 1.0, 1.0, a);
}
