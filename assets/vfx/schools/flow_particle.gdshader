shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform vec4 color : source_color = vec4(1.0);
uniform vec4 hot_color : source_color = vec4(1.0,0.86,0.5,1.0);
uniform float opacity = 1.0;
uniform int kind = 0;
uniform bool billboard = true;
uniform bool use_particle_color = false;
varying vec4 tint;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) { vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f); return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y); }
float fbm(vec2 p) { return noise(p)*0.57+noise(p*2.03)*0.28+noise(p*4.09)*0.15; }
void vertex() {
    tint = use_particle_color ? COLOR : vec4(1.0);
    if (billboard) {
        vec3 s=vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));
        MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*s.x,INV_VIEW_MATRIX[1]*s.y,INV_VIEW_MATRIX[2]*s.z,MODEL_MATRIX[3]);
    }
}
void fragment() {
    vec2 p=UV-0.5;
    float r=length(p)*2.0;
    float n=fbm(UV*5.0+vec2(TIME*0.12,-TIME*0.8));
    float mask=exp(-r*r*5.5)*(1.0-smoothstep(0.55,1.0,r));
    vec3 rgb=color.rgb;
    if (kind==1) {
        float y=1.0-UV.y;
        float x=p.x+sin(y*8.0-TIME*3.4)*0.05+(n-0.5)*0.14*y;
        float w=max(0.015,0.39*(1.0-y));
        mask=(1.0-smoothstep(w*0.25,w,abs(x)))*smoothstep(0.0,0.10,y)*(1.0-smoothstep(0.78,1.0,y));
        mask*=smoothstep(0.10,0.65,n+0.5*(1.0-y));
        rgb=mix(color.rgb,hot_color.rgb,(1.0-y)*pow(max(0.0,1.0-abs(x)/w),2.0));
    } else if (kind==2) {
        mask=(1.0-smoothstep(0.32,1.0,r))*smoothstep(0.23,0.65,n)*0.65;
    } else if (kind==3) {
        float leaf=abs(p.x+sin(UV.y*3.14159)*0.09)/max(0.02,sin(UV.y*3.14159)*0.24);
        mask=(1.0-smoothstep(0.8,1.0,leaf))*smoothstep(0.0,0.10,UV.y)*(1.0-smoothstep(0.88,1.0,UV.y));
        rgb=mix(color.rgb,hot_color.rgb,(1.0-smoothstep(0.0,0.025,abs(p.x)))*0.55);
    } else if (kind==4) {
        float angle=atan(p.y,p.x);
        float curl=sin(angle*3.0+r*12.0-TIME*2.4)*0.5+0.5;
        mask=(1.0-smoothstep(0.2,1.0,r))*(0.25+curl*0.75)*(0.4+n)*1.1;
    } else if (kind==6) {
        float angle=atan(p.y,p.x);
        float curl=fbm(vec2(angle*1.6+r*3.0-TIME*0.5,r*5.0-TIME*0.25));
        mask=(1.0-smoothstep(0.75,1.0,r))*(0.12+curl*0.52);
        rgb=mix(color.rgb,hot_color.rgb,curl*0.6);
    } else if (kind==7) {
        mask=exp(-pow((r-0.72)*14.0,2.0))*(0.5+n*0.5);
    }
    ALBEDO=rgb*tint.rgb;
    EMISSION=rgb*(kind==1?1.6:0.65)*tint.rgb;
    ALPHA=clamp(mask*opacity*color.a*tint.a,0.0,0.95);
}
