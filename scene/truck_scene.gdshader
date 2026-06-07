shader_type canvas_item;

uniform sampler2D palette_texture;
uniform int palette_index = 0;
uniform int palette_width = 10;
uniform int palette_height = 10;

void fragment() {
    vec4 original = texture(TEXTURE, UV);
    vec4 result = original;
    bool found = false;
    
    for (int i = 0; i < palette_width; i++) {
        if (!found) {
            vec2 orig_uv = vec2((float(i) + 0.5) / float(palette_width), 0.0);
            vec4 palette_color = texture(palette_texture, orig_uv);
            
            if (distance(original.rgb, palette_color.rgb) < 0.05) {
                vec2 new_uv = vec2(
                    (float(i) + 0.5) / float(palette_width),
                    (float(palette_index) + 0.5) / float(palette_height)
                );
                result = vec4(texture(palette_texture, new_uv).rgb, original.a);
                found = true;
            }
        }
    }
    
    COLOR = result;
}