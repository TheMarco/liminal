float glyph_bar(vec2 point, vec2 centre, vec2 half_size) {
	vec2 d = abs(point - centre) - half_size;
	float aa = clamp(max(fwidth(point).x, fwidth(point).y) * 0.45, 0.025, 0.15);
	return 1.0 - smoothstep(-aa, aa, max(d.x, d.y));
}

float data_glyph(vec2 point, float random) {
	// Fixed hexadecimal characters. Illumination moves through the code;
	// the characters themselves never flicker or change on every frame.
	int code = int(floor(random * 16.0));
	int mask = 63;
	if (code == 1) { mask = 6; }
	else if (code == 2) { mask = 91; }
	else if (code == 3) { mask = 79; }
	else if (code == 4) { mask = 102; }
	else if (code == 5) { mask = 109; }
	else if (code == 6) { mask = 125; }
	else if (code == 7) { mask = 7; }
	else if (code == 8) { mask = 127; }
	else if (code == 9) { mask = 111; }
	else if (code == 10) { mask = 119; }
	else if (code == 11) { mask = 124; }
	else if (code == 12) { mask = 57; }
	else if (code == 13) { mask = 94; }
	else if (code == 14) { mask = 121; }
	else if (code == 15) { mask = 113; }
	float mark = 0.0;
	if ((mask & 1) != 0) { mark += glyph_bar(point, vec2(0.5, 0.80), vec2(0.15, 0.025)); }
	if ((mask & 2) != 0) { mark += glyph_bar(point, vec2(0.68, 0.65), vec2(0.025, 0.12)); }
	if ((mask & 4) != 0) { mark += glyph_bar(point, vec2(0.68, 0.35), vec2(0.025, 0.12)); }
	if ((mask & 8) != 0) { mark += glyph_bar(point, vec2(0.5, 0.20), vec2(0.15, 0.025)); }
	if ((mask & 16) != 0) { mark += glyph_bar(point, vec2(0.32, 0.35), vec2(0.025, 0.12)); }
	if ((mask & 32) != 0) { mark += glyph_bar(point, vec2(0.32, 0.65), vec2(0.025, 0.12)); }
	if ((mask & 64) != 0) { mark += glyph_bar(point, vec2(0.5, 0.50), vec2(0.15, 0.025)); }
	return min(mark, 1.0);
}
