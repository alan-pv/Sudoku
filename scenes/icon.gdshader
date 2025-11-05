shader_type canvas_item;

void fragment() {
    // Obtener el alpha del píxel original
    float a = texture(TEXTURE, UV).a * COLOR.a;
    // Poner el color RGB a blanco, conservar alpha
    COLOR = vec4(1.0, 1.0, 1.0, a);
}
