#version 440
layout(location=0) in vec2 qt_TexCoord0;
layout(location=0) out vec4 fragColor;
layout(std140,binding=0) uniform buf {
    mat4 qt_Matrix; float qt_Opacity; float time; vec2 resolution;
    float authProgress; float wakePulse; float typingPulse;
    float failureProgress; float successProgress; float authenticationTension;
};
float hash21(vec2 p) { p=fract(p*vec2(123.34,456.21)); p+=dot(p,p+45.32); return fract(p.x*p.y); }
float noise(vec2 p) {
    vec2 i=floor(p), f=fract(p); f=f*f*(3.-2.*f);
    return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+1.),f.x),f.y);
}
mat2 turn(float a){return mat2(cos(a),-sin(a),sin(a),cos(a));}
const vec3 silver=vec3(.72,.64,.86);
const vec3 violet=vec3(.545,.361,.965);
const vec3 lilac=vec3(.655,.545,.980);
// The ring is a plane in 3D. Its z is compared with the sphere surface.
vec3 ring(vec2 p,float sphereZ,float bodyR,float tilt,float offset,float weight) {
    float c=cos(tilt), s=sin(tilt);
    vec2 rp=vec2(p.x,(p.y-offset)/c);
    float r=length(rp), a=atan(rp.y,rp.x);
    float z=rp.y*s;
    float collapse=smoothstep(.08,.8,successProgress);
    float rr=r/(1.-collapse*.50);
    float edge=smoothstep(.77,.81,rr)*(1.-smoothstep(1.40,1.50,rr));
    if(edge<.001 || z<sphereZ) return vec3(0.);
    float phase=a-time*(.062+ .044/(rr*rr));
    float fine=pow(noise(vec2(rr*245., .7)),2.4);
    float strata=noise(vec2(rr*67.,1.5));
    float gaps=1.-.90*exp(-pow((rr-1.075)*105.,2.));
    gaps*=1.-.7*exp(-pow((rr-1.285)*140.,2.));
    float dust=noise(vec2(phase*115.,rr*310.));
    float body=(.10+.65*fine+.22*strata)*(.42+.58*dust)*gaps;
    body += pow(dust,14.) * .65 * gaps;
    vec3 pt=vec3(p.x,p.y,z), L=normalize(vec3(-.55,-.65,1.0));
    float along=dot(pt,L), hit=along*along-dot(pt,pt)+bodyR*bodyR;
    float shadow=1.-.91*smoothstep(-.03,.025,hit)*(1.-smoothstep(-.05,.08,along));
    float front=mix(.38,1.,smoothstep(-.7,.8,z));
    float sector=.78+.22*cos(phase-1.2);
    // PAM wait: one soft highlight travels around the ring.
    float arcD=abs(mod(a-time*2.1+3.14159,6.28318)-3.14159);
    float arc=authenticationTension*exp(-arcD*arcD*9.);
    vec3 ink=mix(violet,silver,.35+.32*strata+.35*arc);
    vec3 col=ink*body*(1.+.9*arc)*edge*front*shadow*sector*weight;
    // Rejection: a single lilac wave crosses the rings from the inner edge out.
    float wave=mix(.74,1.56,failureProgress);
    float band=exp(-pow((rr-wave)/.05,2.))*sin(3.14159*failureProgress);
    col+=lilac*band*(.22+.9*body)*edge*front*shadow*weight*1.2;
    return col;
}
void main(){
    vec2 p=(qt_TexCoord0-.5)*2.; p.x*=resolution.x/max(resolution.y,1.);
    float collapse=smoothstep(.2,1.,successProgress);
    p/=1.+authProgress*.035+wakePulse*.009+collapse*.28;
    p=turn(-.30+.020*sin(time*.11))*p;
    p.y+=typingPulse*.0018*sin(p.x*5.);
    float R=.545+collapse*.26;
    float d=length(p), aa=2./max(resolution.y,1.);
    float mask=1.-smoothstep(R-aa,R+aa,d);
    float sphereZ=d<R?sqrt(max(0.,R*R-d*d)):-100.;
    vec3 color=vec3(0.);
    // Sparse, faint points only within the object's surrounding negative space.
    vec2 g=p*36., cell=floor(g), local=fract(g)-.5;
    float star=(1.-smoothstep(.012,.048,length(local)))*step(.997,hash21(cell));
    float twinkle=.55+.45*sin(time*(.9+hash21(cell+7.)*1.6)+hash21(cell+3.)*40.);
    color+=silver*star*.13*twinkle*smoothstep(.7,1.0,d)*(1.-smoothstep(1.5,2.,d));
    if(d<R+aa){
        vec3 n=normalize(vec3(p,sqrt(max(0.,R*R-dot(p,p)))));
        vec3 L=normalize(vec3(-.65,-.75,.38));
        float diffuse=max(dot(n,L),0.);
        float terrain=noise(p*17.+vec2(time*.006,0.))*.65+noise(p*43.)*.35;
        float limb=pow(1.-max(n.z,0.),4.6);
        float lit=pow(max(dot(n,L),0.),1.6);
        vec3 surface=vec3(.015,.014,.020)*( .18+diffuse*(.75+.3*terrain));
        // Rim light on the lit (left) limb keeps the silhouette apart from the ring shadow.
        surface+=mix(violet,silver,.45)*limb*lit*.74;
        surface+=silver*pow(diffuse,5.)*.035*(.4+terrain*.6);
        color=mix(color,surface,mask);
    }
    color+=ring(p,sphereZ,R,1.12+.020*sin(time*.07),0.,.76);
    color+=ring(turn(.037)*p,sphereZ,R,1.19,.012,.14);
    float atmosphere=exp(-abs(d-R)*260.)*smoothstep(-.1,.7,-p.x-p.y)*.12;
    color+=silver*atmosphere;
    color*=.97+.03*sin(time*.30);
    color*=1.-smoothstep(.58,1.,successProgress);
    fragColor=vec4(color,1.)*qt_Opacity;
}
