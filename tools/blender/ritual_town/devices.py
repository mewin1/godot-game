"""The working assemblies sit astride the ridge. Heights and pivots are shared by all levels."""
import math
from mesh import Meshwork
from houses import RIDGES

FAMILIES = {
    "svarog": ("brazier","furnace","cinder"),
    "ice": ("rime","glacier","ice_lance"),
    "water": ("dew","water","rain"),
    "stribog": ("wind","gale","vortex"),
    "war": ("bolt","war_engine","porok"),
    "perun": ("spark","thunder","storm"),
    "curse": ("hex","plague","doom"),
}


def saddle(m, tier, style="oak"):
    """Two trestles descend through the roof to a wall plate; deck carried by both bents."""
    ridge=RIDGES[tier-1]
    z=ridge+(.045,.24,.235)[tier-1]
    w=(.14,.215,.245)[tier-1]
    for x in [-w,w]:
        for y in [-w,w]:
            m.beam((x*1.14,y*1.22,ridge-.21),(x,y,z),.084,style)
        if tier>1:
            m.beam((x,-w,ridge-.12),(x,w,z-.012),.057,"carving")
    m.box((0,0,z),(2*w+.106,2*w+.09,.073),"heartwood")
    return z+.035


def fire(tier):
    m=Meshwork()
    if tier==1:
        x,y=.28,.06
        z=.91
        m.box((x,y,z+.085),(.235,.21,.34),"plinth")
        m.turned((x,y,z+.23),[(0,.102),(.095,.175),(.115,.168)],"iron")
        m.turned((x,y,z+.34),[(0,.137),(.044,.083),(.065,.045)],"ember")
        return m,None,(x,y,z+.38),None
    if tier==2:
        x,y=.11,.04
        z=.97
        m.turned((x,y,z),[(0,.27),(.29,.245),(.325,.26)],"plinth",4)
        m.turned((x,y,z+.32),[(0,.25),(.14,.21)],"ember",4)
        for i in range(4):
            a=math.tau*i/4
            m.beam((x+.23*math.cos(a),y+.23*math.sin(a),z+.32),
                   (x+.21*math.cos(a),y+.21*math.sin(a),z+.47),.052,"iron")
        m.turned((x,y,z+.46),[(0,.256),(.08,.218),(.40,.17),(.44,.191),(.49,.189)],"iron",4)
        m.turned((x,y,z+.951),[(0,.108),(.003,.106)],"soot",4)
        return m,None,(x,y,z+.955),None
    z=saddle(m,tier,"heartwood")
    m.turned((0,0,z),[(0,.195),(.105,.167),(.19,.35),(.236,.374)],"copper")
    m.turned((0,0,z+.225),[(0,.337),(.013,.23),(.04,.174)],"ember")
    # Raised dark ring makes a legible rim around the orange working face.
    m.hoop((0,0,z+.26),.338,.029,"iron",16)
    for i in range(8):
        a=math.tau*i/8
        def p(r,h):
            return (r*math.cos(a),r*math.sin(a),z+h)
        m.span(p(.253,.09),p(.35,.24),.044,.037,"iron",5)
        m.span(p(.35,.24),p(.425,.54 if i%2==0 else .39),.041,.009,"brass",5)
    for x,y,h in [(-.074,0,.43),(.067,.032,.55),(0,-.06,.375)]:
        m.span((x,y,z+.27),(x+.03,y+.024,z+h),.071,.013,"ember",7)
    return m,None,(0,0,z+.55),None


def shard(m, a, b, radius, material="frost", sides=6):
    # A faceted shoulder and narrow terminal keep the cut distinct from a round pipe.
    neck=tuple(a[i]*.33+b[i]*.67 for i in range(3))
    m.span(a,neck,radius*.72,radius,material,sides)
    m.span(neck,b,radius,.006,material,sides)


def frost(tier):
    m=Meshwork()
    z=saddle(m,tier)
    if tier==1:
        m.turned((0,0,z),[(0,.12),(.08,.16),(.12,.15)],"steel",8)
        for x,y,h in [(-.14,.03,.28),(.044,.085,.40),(.15,-.08,.22)]:
            shard(m,(x*.28,y*.5,z+.075),(x,y,z+h),.071)
        top=(.044,.085,z+.40)
    elif tier==2:
        # Ice store: broad hanging ice block clasped in a square timber bearer.
        for x in [-.19,.19]:
            m.beam((x,-.185,z),(x,-.185,z+.32),.045,"steel")
        m.box((0,0,z+.175),(.42,.39,.32),"frost",.055)
        for y in [-.215,.215]:
            m.box((0,y,z+.031),(.51,.043,.061),"verdigris")
        for x,y in [(-.13,-.186),(.16,-.196),(.21,.07)]:
            m.span((x,y,z+.09),(x+.009,y,z-.11),.044,.005,"frost",5)
        top=(0,0,z+.35)
    else:
        for x in [-.14,.14]:
            m.beam((x,-.22,z),(x,-.028,z+.28),.09,"iron")
            m.beam((x,.20,z),(x,-.028,z+.28),.09,"carving")
        a,b=(-.41,.065,z+.19),(.65,-.10,z+.565)
        m.span(a,(-.09,.024,z+.285),.105,.14,"steel",8)
        shard(m,(-.17,.025,z+.27),b,.133)
        m.span((-.105,.023,z+.281),(-.059,.018,z+.294),.14,.144,"brass",8)
        top=b
    return m,None,top,None


def basin(m,x,y,z,r,depth):
    m.turned((x,y,z),[(0,r*.62),(depth*.18,r*.66),(depth*.8,r),
                       (depth,r),(depth+.018,r*.91)],"copper",16)
    m.turned((x,y,z+depth+.016),[(0,r*.88),(.007,r*.875)],"pool",18)
    m.hoop((x,y,z+depth+.019),r*.96,.017,"verdigris")


def waterworks(tier):
    m=Meshwork()
    z=saddle(m,tier)
    if tier==1:
        basin(m,0,0,z,.225,.15)
        m.span((.12,.1,z+.05),(.12,.1,z+.295),.026,.026,"copper")
        m.span((.12,.1,z+.295),(-.022,.06,z+.295),.026,.026,"copper")
        m.span((-.022,.06,z+.295),(-.022,.06,z+.17),.012,.014,"pool")
        top=(0,0,z+.20)
    elif tier==2:
        # Folded timber flume. Sloped cheek boards expose the blue water ribbon above.
        for x in [-.38,.34]:
            for y in [-.14,.14]:
                m.beam((x*.55,y,z-.032),(x,y,z+.155+x*.12),.048)
        for y in [-.158,.158]:
            m.beam((-.48,y,z+.14),(.45,y,z+.265),.066,"carving")
        pts=[(-.48,-.142,z+.13),(.45,-.142,z+.251),(.45,.142,z+.251),(-.48,.142,z+.13)]
        m.face(pts,"pool")
        for y in [-.15,.15]:
            m.beam((-.48,y,z+.085),(.45,y,z+.20),.072,"heartwood")
        m.box((.44,0,z+.245),(.055,.34,.105),"copper")
        m.span((-.46,0,z+.12),(-.49,0,z-.09),.041,.028,"pool",8)
        top=(-.47,0,z+.14)
    else:
        basin(m,0,0,z,.329,.145)
        m.turned((0,0,z+.125),[(0,.11),(.19,.067),(.285,.094)],"verdigris")
        m.hoop((0,0,z+.39),.385,.036,"copper",20)
        for i in range(6):
            a=i*math.tau/6
            x,y=math.cos(a),math.sin(a)
            m.span((0,0,z+.375),(.385*x,.385*y,z+.39),.021,.027,"brass")
            m.span((.385*x,.385*y,z+.39),(.34*x,.34*y,z+.292),.034,.028,"verdigris")
            m.span((.34*x,.34*y,z+.29),(.267*x,.267*y,z+.15),.017,.021,"pool",6)
        m.turned((0,0,z+.389),[(0,.10),(.044,.076),(.058,.042)],"pool")
        top=(0,0,z+.415)
    return m,None,top,None


def sailwheel(m,x,y,z,radius,blades):
    # Linen is stretched on spars with a broad outer hem and a slight twist.
    for i in range(blades):
        a=math.tau*i/blades+.38
        def p(r,t,dy):
            return (x+math.cos(a)*r-math.sin(a)*t,y+dy,z+math.sin(a)*r+math.cos(a)*t)
        m.beam(p(.025,0,0),p(radius,0,.008),.033,"carving")
        pts=[p(radius*.29,.009,-.002),p(radius*.94,.012,.006),
             p(radius*.91,radius*.36,-.042),p(radius*.44,radius*.22,-.031)]
        m.face(pts,"linen")
        m.face(pts[::-1],"linen")
        m.beam(p(radius*.91,radius*.27,-.04),p(radius*.94,0,.006),.021,"oak")
    m.span((x,y-.049,z),(x,y+.055,z),radius*.14,radius*.13,"brass",10)


def windworks(tier):
    m=Meshwork()
    z=saddle(m,tier)
    if tier==2:
        # A tuned wind horn accepts air from a roof scoop. Bell faces the working direction.
        m.turned((0,0,z),[(0,.15),(.11,.115),(.30,.075),(.36,.095)],"verdigris")
        m.span((0,.12,z+.33),(0,-.13,z+.35),.069,.089,"brass")
        m.span((0,-.13,z+.35),(0,-.36,z+.395),.089,.183,"brass",12)
        m.span((0,-.362,z+.395),(0,-.367,z+.396),.147,.145,"soot",12)
        return m,None,(0,-.34,z+.395),None
    radius=.32 if tier==1 else .52
    h=z+(.26 if tier==1 else .41)
    for x in [-.12,.12]:
        m.beam((x,-.025,z),(0,-.07,h),.073,"carving")
    m.span((0,.135,h),(0,-.255,h),.067,.072,"copper")
    if tier==3:
        m.turned((0,0,z),[(0,.213),(.15,.156),(.204,.19)],"verdigris",8)
        for x in [-.225,.225]:
            m.beam((x,.155,z),(0,.04,h),.062,"brass")
    moving=Meshwork()
    pivot=(0,-.258,h)
    sailwheel(moving,*pivot,radius,4 if tier==1 else 6)
    return m,moving,(0,-.27,h),pivot


def bow(m,center,size):
    # Bent laminated prod and visible string meeting the drawn carriage.
    x,y,z=center
    for s in [-1,1]:
        pts=[(x,y,z),(x+s*size*.63,y+.036,z+.025),(x+s*size,y+.14,z+.071)]
        m.span(pts[0],pts[1],.047,.030,"heartwood",6)
        m.span(pts[1],pts[2],.03,.014,"carving",6)
        m.span(pts[2],(x,y+.28,z+.031),.008,.008,"rope",5)
    m.beam((x,y-.12,z),(x,y+.34,z+.032),.077,"oak")
    m.span((x,y+.235,z+.064),(x,y-.16,z+.045),.016,.018,"steel")


def mechanisms(tier):
    m=Meshwork()
    moving=None
    pivot=None
    z=saddle(m,tier)
    if tier<3:
        h=z+(.125 if tier==1 else .24)
        m.turned((0,0,z),[(0,.14),(.07,.126),(h-z,.089)],"iron")
        if tier==1:
            bow(m,(0,-.135,h),.346)
        else:
            m.beam((-.28,0,h),(.28,0,h),.082,"iron")
            for x in [-.234,.234]:
                m.beam((x,-.1,z),(x,-.09,h+.024),.093,"carving")
                bow(m,(x,-.14,h+.025),.219)
            m.span((-.285,.16,z+.085),(.285,.16,z+.085),.075,.075,"iron")
        top=(0,-.23,h+.052)
    else:
        h=z+.36
        for y in [-.175,.175]:
            for x in [-.245,.245]:
                m.beam((x,y,z),(0,y,h),.084,"carving")
            m.beam((-.25,y,z+.017),(.25,y,z+.017),.073,"heartwood")
        m.span((0,-.24,h),(0,.24,h),.078,.078,"iron")
        moving=Meshwork()
        pivot=(0,0,h)
        moving.beam((-.26,0,h-.145),(.48,0,h+.32),.106,"oak")
        moving.box((-.272,0,h-.188),(.235,.264,.202),"iron",.021)
        for y in [-.052,.052]:
            moving.span((.48,0,h+.32),(.58,y,h+.15),.012,.012,"rope",5)
        moving.turned((.58,0,h+.079),[(0,.053),(.035,.102),(.097,.086),(.136,.035)],"plinth",8)
        top=(.58,0,h+.19)
    return m,moving,top,pivot


def ion(m,x,y,z,h):
    m.turned((x,y,z),[(0,.068),(h,.046)],"copper")
    for t in [.22,.46,.69]:
        m.turned((x,y,z+h*t),[(0,.083),(.033,.063)],"pottery",10)
    m.turned((x,y,z+h),[(0,.046),(.035,.063),(.077,.042),(.09,.023)],"charge",8)


def lightning(tier):
    m=Meshwork()
    z=saddle(m,tier)
    if tier==1:
        for x in [-.114,.114]:
            ion(m,x,0,z,.14 if x<0 else .20)
        m.span((-.12,0,z+.102),(.12,0,z+.113),.024,.025,"brass")
        top=(.114,0,z+.28)
    elif tier==2:
        m.turned((0,0,z),[(0,.176),(.105,.12),(.16,.092)],"pottery")
        ion(m,0,0,z+.145,.32)
        for x in [-.155,.155]:
            m.span((0,0,z+.26),(x,.015,z+.355),.025,.02,"brass")
            shard(m,(x,.015,z+.355),(x*.91,.015,z+.46),.033,"charge",5)
        top=(0,0,z+.55)
    else:
        for x in [-.274,.274]:
            for y in [-.198,.198]:
                m.beam((x*.68,y*.72,z),(x,y,z+.2),.06,"iron")
                ion(m,x,y,z+.185,.146)
            m.span((x,-.195,z+.264),(x,.195,z+.264),.023,.023,"copper")
        for y in [-.198,.198]:
            m.span((-.274,y,z+.264),(.274,y,z+.264),.025,.025,"copper")
        m.turned((0,0,z),[(0,.14),(.25,.095),(.32,.125)],"pottery",8)
        shard(m,(0,0,z+.28),(0,0,z+.53),.08,"charge",6)
        for x,y in [(-.27,-.198),(.27,.198)]:
            m.span((x,y,z+.299),(0,0,z+.385),.016,.016,"steel",6)
        top=(0,0,z+.52)
    return m,None,top,None


def curse(tier):
    m=Meshwork()
    z=saddle(m,tier)
    if tier==1:
        m.beam((0,.04,z),(0,.04,z+.32),.075,"heartwood")
        m.turned((0,-.01,z+.115),[(0,.063),(.08,.132),(.205,.139),(.264,.071)],"bone",8)
        for x in [-.045,.045]:
            m.box((x,-.137,z+.279),(.043,.015,.049),"soot")
        m.box((0,-.126,z+.213),(.027,.02,.055),"rune")
        top=(0,0,z+.34)
    elif tier==2:
        for x in [-.239,.239]:
            m.beam((x,0,z),(x,.015,z+.44),.073,"heartwood")
        m.beam((-.31,.015,z+.434),(.31,.015,z+.434),.082,"carving")
        m.span((0,0,z+.442),(0,0,z+.315),.028,.033,"iron",8)
        bell=Meshwork()
        bell.turned((0,0,z+.066),[(0,.196),(.045,.201),(.084,.16),(.19,.128),(.24,.092),(.255,.067)],"iron",16)
        bell.hoop((0,0,z+.128),.169,.018,"pottery")
        bell.span((0,0,z+.085),(0,-.047,z+.018),.031,.046,"rune")
        return m,bell,(0,0,z+.31),(0,0,z+.32)
    else:
        m.turned((0,0,z),[(0,.29),(.059,.29),(.092,.232)],"slate",4)
        m.turned((0,0,z+.085),[(0,.235),(.375,.171),(.51,.144),(.75,.012)],"slate",4)
        m.turned((0,0,z+.40),[(0,.181),(.055,.17)],"pottery",4)
        # Inlaid branching sigil facing the street, following the tapered front facet.
        for s in [-1,1]:
            a=(0,-.205,z+.19)
            b=(s*.077,-.113,z+.313)
            c=(0,-.177,z+.384)
            m.beam(a,b,.026,"rune")
            m.beam(b,c,.026,"rune")
        m.beam((0,-.204,z+.16),(0,-.153,z+.553),.029,"rune")
        top=(0,0,z+.77)
    return m,None,top,None


BUILDERS={"svarog":fire,"ice":frost,"water":waterworks,"stribog":windworks,
          "war":mechanisms,"perun":lightning,"curse":curse}


def device(school,tier):
    return BUILDERS[school](tier)
