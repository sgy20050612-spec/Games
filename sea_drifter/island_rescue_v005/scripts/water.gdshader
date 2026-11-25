shader_type canvas_item;
render_mode unshaded;

uniform sampler2D reflection_map : filter_nearest, repeat_disable;
uniform vec2 resolution = vec2(1152.0,648.0);
uniform vec2 world_offset = vec2(0.0);
uniform float island_size = 896.0;
uniform float night = 0.0;
uniform float sunset = 0.0;
uniform vec4 day_color : source_color = vec4(0.10,0.48,0.79,1.0);
uniform vec4 night_color : source_color = vec4(0.035,0.12,0.29,1.0);

float hash(vec2 p) {
 return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);
}

float coast_distance(vec2 p) {
 vec2 q=abs(p-vec2(island_size*0.5))-vec2(island_size*0.5-36.0);
 float shape=length(max(q,vec2(0.0)))+min(max(q.x,q.y),0.0)-96.0;
 float noise=sin(p.x*0.009+p.y*0.003)*11.0+sin(p.y*0.019-p.x*0.007)*6.0+sin(p.x*0.037+p.y*0.029)*2.0;
 return shape-noise;
}

void fragment() {
 vec2 pixel=floor(UV*resolution/2.0)*2.0;
 vec2 world=pixel-world_offset;
 float slow_time=TIME*0.42;
 float swell=sin(world.y*0.038+sin(world.x*0.012+slow_time)*1.6+slow_time);
 float cross_swell=sin(world.y*0.075+world.x*0.006-slow_time*0.7);
 float grain=hash(floor(world/vec2(22.0,7.0)));
 vec3 water=mix(day_color.rgb,night_color.rgb,night);
 water=mix(water,vec3(0.39,0.35,0.40),sunset*0.5);
 water*=0.92+0.06*swell+0.025*cross_swell+0.018*grain;
 float lines=step(0.94,sin(world.y*0.21+sin(world.x*0.019+slow_time)*1.7+slow_time*1.5));
 lines*=step(0.42,hash(floor(world/vec2(28.0,6.0))));
 water+=mix(vec3(0.09,0.16,0.15),vec3(0.05,0.09,0.15),night)*lines*0.38;

 // Original scene sprites are reflected into a small transparent viewport.
 // A row-wise two-pixel displacement keeps the reflection deliberately pixelated.
 vec2 distorted=UV;
 distorted.x+=(sin(world.y*0.26+TIME*1.1)+sin(world.y*0.07-TIME*0.7))*1.6/resolution.x;
 distorted.y+=sin(world.x*0.035+slow_time)*0.55/resolution.y;
 vec4 reflected=texture(reflection_map,distorted);
 float breaks=mix(0.50,0.90,step(0.03,sin(world.y*0.46+TIME*0.65)));
 vec3 reflected_color=reflected.rgb/max(reflected.a,0.001);
 reflected_color*=mix(vec3(1.0),vec3(0.60,0.73,0.90),night*0.50);
 water=mix(water,mix(reflected_color,water,0.34),reflected.a*breaks*0.72);

 float coast=coast_distance(world);
 float shallow=1.0-smoothstep(3.0,46.0,coast);
 water=mix(water,water*1.17+mix(vec3(0.035,0.065,0.045),vec3(0.02,0.03,0.04),night),shallow*0.62);

 // Narrow broken trails of moonlight / late-sun shimmer, brightest near the harbor.
 float light_x=island_size*0.52+sin(world.y*0.025+slow_time)*11.0;
 float width=20.0+clamp((world.y-island_size)*0.22,0.0,60.0);
 float path=exp(-pow(abs(world.x-light_x)/width,2.0));
 float glints=step(0.80,sin(world.y*0.38+sin(world.x*0.12)+TIME*0.4));
 float below=step(island_size+14.0,world.y);
 water+=vec3(0.22,0.26,0.25)*path*glints*below*(night*0.26+sunset*0.22+0.025);
 // Continuous dry sand -> damp sand -> shallows. Two-pixel clustered dithering
 // breaks the grass edge without a hard rectangular tile border.
 vec3 dry_sand=vec3(0.96,0.77,0.42);
 vec3 wet_sand=vec3(0.80,0.64,0.38);
 float fleck=hash(floor(world/2.0))-0.5;
 vec3 sand=mix(dry_sand,wet_sand,smoothstep(-24.0,-5.0,coast))+fleck*0.025;
 float grass_edge=coast+sin(world.x*0.18+world.y*0.09)*2.0+sin(world.y*0.27)*1.4;
 float grass_mix=1.0-smoothstep(-57.0,-43.0,grass_edge);
 float clustered=hash(floor(world/vec2(4.0,3.0)));
 float grass_mask=step(clustered,grass_mix);
 vec3 grass=vec3(0.34,0.65,0.18)*(0.98+sin(world.x*0.014+world.y*0.007)*0.016+cos(world.y*0.018)*0.012)+fleck*0.028;
 vec3 land=mix(sand,grass,grass_mask);
 land*=mix(vec3(1.0),vec3(0.55,0.67,0.80),night*0.78);
 land=mix(land,land*vec3(1.12,0.98,0.84),sunset*0.5);
 if (coast<0.0) { water=land; }
 float tide=sin(TIME*0.66+world.x*0.009+world.y*0.006)*2.6;
 float foam=(1.0-smoothstep(0.3,2.3,abs(coast-1.0-tide)));
 foam*=step(0.24,hash(floor(world/vec2(7.0,5.0))));
 water=mix(water,mix(vec3(0.76,0.94,0.91),vec3(0.39,0.51,0.61),night),foam*0.65);
 COLOR=vec4(water,1.0);
}
