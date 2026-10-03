shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

uniform float wave_strength = 1.0;
uniform float wave_speed = 20.0;
uniform float wave_size = 10.0;

void fragment() {
    vec2 pixel = SCREEN_PIXEL_SIZE;

    float wave_x = sin(SCREEN_UV.y * wave_size + TIME * wave_speed);
    float wave_y = cos(SCREEN_UV.x * wave_size + TIME * wave_speed);

    vec2 offset = vec2(wave_x, wave_y) * pixel * wave_strength;

    vec2 uv = SCREEN_UV + offset;

    vec3 current = texture(screen_texture, uv).rgb;
    vec3 right = texture(screen_texture, uv + vec2(pixel.x, 0.0)).rgb;
    vec3 down = texture(screen_texture, uv + vec2(0.0, pixel.y)).rgb;

    float difference = distance(current, right) + distance(current, down);

    float result = step(0.1, difference);

    COLOR = vec4(result, result, result, 1.0);
}