"""Plot-centred bodies and roofs, in Blender Z-up, street front at -Y."""
from mesh import Meshwork

# Tiers share door, window and beam scales. Wall height rises once, with the tier.
EAVES = (.66, .73, .81)
RIDGES = (1.04, 1.17, 1.36)
WIDTH = (.64,.68,.69)
DEPTH = (.50,.54,.56)


def window(m, x, y, z, side=False):
    def part(dx,dy,dz,w,d,h,mat):
        if side:
            m.box((x-dy,y+dx,z+dz),(d,w,h),mat)
        else:
            m.box((x+dx,y+dy,z+dz),(w,d,h),mat)
    part(0,0,0,.27,.045,.28,"heartwood")
    part(0,-.025,0,.19,.025,.178,"glass")
    part(0,-.044,0,.019,.02,.19,"oak")
    part(0,-.044,.015,.19,.02,.018,"oak")
    part(0,-.024,.136,.31,.066,.042,"carving")
    part(0,-.035,-.132,.30,.077,.045,"carving")


def body(tier, level):
    m = Meshwork()
    w,d,e = WIDTH[tier-1],DEPTH[tier-1],EAVES[tier-1]
    wall = ("oak","plaster","stone","brick")[level-1]
    trim = "lime" if level == 4 else "carving"
    # A low dressed sill receives the four existing rows of bronze level marks.
    m.box((0,0,.062),(1.75,1.69,.124),"plinth",.035)
    m.box((0,0,.123),(1.71,1.66,.03),"plinth",.015)
    m.box((0,0,(e+.13)/2),(w*2,d*2,e-.13),wall,.013)
    # The end gables meet the underside of each roof.
    r = RIDGES[tier-1]-.045
    for sign in [-1,1]:
        x = sign*w
        pts=[(x,-d,e-.025),(x,d,e-.025),(x,0,r)]
        m.face(pts if sign>0 else pts[::-1],wall)
        m.beam((x,0,e),(x,0,r),.067,"oak")
    if level == 1:
        for row in range(4):
            z = .20 + row*.109
            for sign in [-1,1]:
                m.span((-w-.028,sign*d,z),(w+.029,sign*d,z+.005),.066,.065,"oak",8)
                m.span((sign*w,-d-.045,z+.053),(sign*w,d+.043,z+.055),.06,.061,"carving" if row==3 else "oak",8)
    else:
        for x in [-w,w]:
            for y in [-d,d]:
                if level == 2:
                    m.box((x,y,(e+.12)/2),(.068,.071,e-.12),"oak")
                else:
                    for j in range(4):
                        m.box((x,y,.19+j*(e-.14)/4),(.12 if j%2 else .092,.11,(e-.15)/4-.008),
                              "lime" if level==4 else "stone",.011)
        if level == 2:
            for sign in [-1,1]:
                m.beam((sign*(w-.02),-d-.01,e-.09),(sign*(w-.27),-d-.01,.16),.048)
    for y in [-d,d]:
        m.box((0,y,e-.024),(w*2+.12,.088,.081),"heartwood")
    for x in [-w,w]:
        m.box((x,0,e-.021),(.082,d*2+.15,.081),"oak")
    # Plank door, lintel, hinges, threshold and a regularly scaled inhabited window.
    dx = -.17
    m.box((dx,-d-.018,.347),(.295,.051,.46),trim)
    m.box((dx,-d-.048,.332),(.218,.039,.401),"heartwood")
    m.box((dx,-d-.071,.34),(.166,.013,.34),"oak")
    for z in [.228,.437]:
        m.box((dx-.043,-d-.085,z),(.10,.019,.026),"iron")
    m.box((dx,-d-.062,.573),(.34,.105,.054),trim)
    m.box((dx,-d-.13,.072),(.38,.23,.105),"plinth",.018)
    window(m,.32,-d-.03,.405)
    window(m,w+.03,-.08,.41,True)
    if level == 4:
        # Light belt, door surround and alternating quoins above the darker fired brick.
        for sign in [-1,1]:
            m.box((0,sign*d,.185),(w*2+.04,.058,.062),"lime")
            m.box((sign*w,0,.185),(.058,d*2+.04,.062),"lime")
        m.box((.32,-d-.071,.555),(.35,.062,.058),"lime")
    if level>=3:
        m.box((0,d,.15),(2*w+.10,.10,.075),trim if level==4 else "stone")
    return m


def roof(tier, school):
    m=Meshwork()
    e,r,w,d=EAVES[tier-1],RIDGES[tier-1],WIDTH[tier-1]+.125,DEPTH[tier-1]+.135
    # Curved pestry roof with a kicked eave and raised ridge ends.
    def point(x, side, t):
        z = e + (r-e)*(1-t)**1.34 + (.038 if tier>1 else .02)*(abs(x)/w)**3
        if tier==3:
            z += .048*(1-t)*(abs(x)/w)**2
        return (x,side*d*t,z)
    for side in [-1,1]:
        for band in range(4):
            t0,t1=band/4,(band+1)/4
            for j in range(4):
                x0,x1=-w+j*w/2,-w+(j+1)*w/2
                pts=[point(x0,side,t0),point(x1,side,t0),point(x1,side,t1),point(x0,side,t1)]
                uv=[(j/4,1-t0),((j+1)/4,1-t0),((j+1)/4,1-t1),(j/4,1-t1)]
                if side<0:
                    pts.reverse()
                    uv.reverse()
                m.face(pts,school,uv)
            for x in [-w,w]:
                a,b=point(x,side,t0),point(x,side,t1)
                m.beam(a,b,.059 if tier==1 else .076,"oak" if tier==1 else "carving")
        for j in range(4):
            a,b=point(-w+j*w/2,side,1),point(-w+(j+1)*w/2,side,1)
            m.beam(a,b,.07,"heartwood")
        for j in range(6 if tier>1 else 4):
            x=-w+.09+j*(2*w-.18)/(5 if tier>1 else 3)
            m.beam((x,side*(d-.16),e-.073),(x,side*(d+.016),e-.039),.048,"carving")
    for j in range(4):
        x0,x1=-w+j*w/2,-w+(j+1)*w/2
        m.span(point(x0,1,0),point(x1,1,0),.036,.038,"heartwood" if tier==1 else "copper",8)
    for sign in [-1,1]:
        a=point(sign*(w-.08),1,0)
        m.beam(a,(sign*(w+.025),0,a[2]+(.065 if tier<3 else .12)),.049,"carving")
    if tier >= 2:
        # Entrance cross-gable has its own triangular pediment, deep soffit and metal drip.
        hw=.24 if tier==2 else .42
        cx=-.17 if tier==2 else 0
        top=r-.08 if tier==2 else r+.072
        front,back=-d-.066,-.21
        edge=e+.045
        m.face([(cx-hw,front,edge),(cx+hw,front,edge),(cx,front,top)],"oak")
        for s in [-1,1]:
            pts=[(cx,front,top),(cx+s*hw,front,edge),(cx+s*hw,back,edge+.11),(cx,back,top+.055)]
            uv=[(.05,.95),(.05,.12),(.86,.12),(.86,.95)]
            if s<0:
                pts.reverse()
                uv.reverse()
            m.face(pts,school,uv)
            m.beam((cx,front,top),(cx+s*hw,front,edge),.055,"carving")
        m.box((cx,front-.008,edge+.095),(.102,.028,.135),"soot")
        m.box((cx,front-.024,edge+.09),(.068,.02,.096),"glass")
        m.beam((cx-hw,front,edge),(cx+hw,front,edge),.057,"heartwood")
        m.beam((cx,front-.032,top),(cx,back,top+.056),.046,"copper")
        if tier==3:
            # Two broad metal straps run down the front slope and turn over the lip.
            for sign in [-1,1]:
                x=sign*w*.77
                for band in range(3):
                    m.beam(point(x,-1,band/3),point(x,-1,(band+1)/3),.032,"copper")
        if tier==3:
            for s in [-1,1]:
                m.beam((cx+s*.09,front-.025,edge+.05),(cx+s*.18,front-.025,edge+.18),.035,"carving")
    return m
