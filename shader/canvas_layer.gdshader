shader_type canvas_item;

uniform vec4 night_color : source_color = vec4(0.05, 0.05, 0.15, 0.5);

void fragment() {
    COLOR = night_color;
}