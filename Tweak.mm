#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>

// ── config ────────────────────────────────────────────────────────────────────
static const CGFloat kW   = 220.f;
static const CGFloat kH   = 220.f;
static const CGFloat kHdr = 34.f;
static const CGFloat kBtn = 22.f;
static const CGFloat kRow = 30.f;

#define kCOL_BG     [UIColor colorWithRed:.07f green:.07f blue:.08f alpha:1]
#define kCOL_HDR    [UIColor colorWithRed:.11f green:.11f blue:.13f alpha:1]
#define kCOL_ACC    [UIColor colorWithRed:.15f green:.55f blue:1.f  alpha:1]
#define kCOL_BORDER [UIColor colorWithWhite:.18f alpha:1]
#define kCOL_SUB    [UIColor colorWithWhite:.45f alpha:1]
#define kCOL_ESP    [UIColor colorWithRed:0.f   green:.85f blue:.2f alpha:1]
#define kCOL_ROW    [UIColor colorWithWhite:.10f alpha:1]

// ── il2cpp types ──────────────────────────────────────────────────────────────
typedef struct { float x, y, z; } Vec3;

// ── il2cpp bridge ─────────────────────────────────────────────────────────────
static uintptr_t _base = 0;

// exported symbols
static void*        (*_domain_get)(void);
static void*        (*_domain_get_assemblies)(void*, size_t*);
static void*        (*_assembly_get_image)(void*);
static const char*  (*_image_get_name)(void*);
static void*        (*_class_from_name)(void*, const char*, const char*);
static void*        (*_class_get_type)(void*);
static void*        (*_type_get_object)(void*);

// RVA methods (dump base 0x112a70000, offsets = RVA as listed)
// PlayerController.get_IsDeath   RVA 0x1579C24
// Component.get_transform        RVA 0x2BAA1E8
// Transform.get_position_Inj     RVA 0x2BB48F4
// Camera.get_main                RVA 0x2B741F0
// Camera.WorldToScreenPoint_Inj  RVA 0x2B73ED8
// Object.FindObjectsOfType(T,b)  RVA 0x2BAF53C
static bool  (*_IsDeath)  (void* pc);
static void* (*_GetTr)    (void* comp);
static void  (*_GetPos)   (void* tr, Vec3* out);
static void* (*_CamMain)  (void);
static void  (*_W2SP)     (void* cam, Vec3* pos, int eye, Vec3* out);
static void* (*_FindOT)   (void* typeObj, bool inactive, void* method);

static void* _pcKlass    = NULL;
static void* _pcTypeObj  = NULL;

#define RVA(off) (void*)(_base + (off))

static uintptr_t findBase(void) {
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *n = _dyld_get_image_name(i);
        if (n && strstr(n, "GameAssembly"))
            return (uintptr_t)_dyld_get_image_header(i);
    }
    return 0;
}

static void setupBridge(void) {
    _base = findBase();
    if (!_base) return;

#define SYM(fn, s) fn = (typeof(fn))dlsym(RTLD_DEFAULT, s)
    SYM(_domain_get,            "il2cpp_domain_get");
    SYM(_domain_get_assemblies, "il2cpp_domain_get_assemblies");
    SYM(_assembly_get_image,    "il2cpp_assembly_get_image");
    SYM(_image_get_name,        "il2cpp_image_get_name");
    SYM(_class_from_name,       "il2cpp_class_from_name");
    SYM(_class_get_type,        "il2cpp_class_get_type");
    SYM(_type_get_object,       "il2cpp_type_get_object");
#undef SYM

    _IsDeath = (typeof(_IsDeath)) RVA(0x1579C24);
    _GetTr   = (typeof(_GetTr))   RVA(0x2BAA1E8);
    _GetPos  = (typeof(_GetPos))  RVA(0x2BB48F4);
    _CamMain = (typeof(_CamMain)) RVA(0x2B741F0);
    _W2SP    = (typeof(_W2SP))    RVA(0x2B73ED8);
    _FindOT  = (typeof(_FindOT))  RVA(0x2BAF53C);

    if (!_domain_get || !_class_from_name || !_class_get_type || !_type_get_object) return;

    void *domain = _domain_get();
    if (!domain) return;

    size_t count = 0;
    void **asm_list = (void**)_domain_get_assemblies(domain, &count);
    if (!asm_list) return;

    for (size_t i = 0; i < count; i++) {
        void *img = _assembly_get_image(asm_list[i]);
        if (!img) continue;
        const char *name = _image_get_name(img);
        if (name && strcmp(name, "Assembly-CSharp.dll") == 0) {
            _pcKlass = _class_from_name(img, "", "PlayerController");
            break;
        }
    }

    if (_pcKlass) {
        void *t = _class_get_type(_pcKlass);
        if (t) _pcTypeObj = _type_get_object(t);
    }
}

// ── esp state ─────────────────────────────────────────────────────────────────
static BOOL  g_espOn    = NO;
static float g_espDist  = 150.f;

#define kMaxP 16
static void*         g_players[kMaxP];
static int           g_pCount    = 0;
static NSTimeInterval g_lastUpd  = 0;

static void refreshPlayers(void) {
    if (!_pcTypeObj || !_FindOT) return;
    void *arr = _FindOT(_pcTypeObj, false, NULL);
    if (!arr) { g_pCount = 0; return; }
    size_t len = *(size_t*)((uint8_t*)arr + 0x18);
    g_pCount = 0;
    for (size_t i = 0; i < len && g_pCount < kMaxP; i++) {
        void *pc = *(void**)((uint8_t*)arr + 0x20 + i * 8);
        if (pc) g_players[g_pCount++] = pc;
    }
}

// ── esp overlay ───────────────────────────────────────────────────────────────
@interface ESPView : UIView @end
@implementation ESPView
- (instancetype)initWithFrame:(CGRect)f {
    self = [super initWithFrame:f];
    self.backgroundColor        = [UIColor clearColor];
    self.userInteractionEnabled = NO;
    return self;
}
- (void)drawRect:(CGRect)rect {
    if (!g_espOn || g_pCount == 0) return;
    if (!_GetTr || !_GetPos || !_CamMain || !_W2SP) return;

    void *cam = _CamMain();
    if (!cam) return;

    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(ctx, kCOL_ESP.CGColor);
    CGContextSetLineWidth(ctx, 1.1f);

    CGFloat sh = self.bounds.size.height;

    for (int i = 0; i < g_pCount; i++) {
        void *pc = g_players[i];
        if (!pc) continue;
        if (_IsDeath && _IsDeath(pc)) continue;

        void *tr = _GetTr(pc);
        if (!tr) continue;

        Vec3 feet, head;
        _GetPos(tr, &feet);
        head = (Vec3){ feet.x, feet.y + 1.78f, feet.z };

        Vec3 sf, sh2;
        _W2SP(cam, &feet, 0, &sf);
        _W2SP(cam, &head, 0, &sh2);

        if (sf.z < 0.1f) continue;           // за камерой
        if (g_espDist > 0.f && sf.z > g_espDist) continue;

        CGFloat fy = sh - sf.y;
        CGFloat hy = sh - sh2.y;
        CGFloat bh = fy - hy;
        if (bh < 6.f) continue;

        CGFloat bw = bh * 0.38f;
        CGRect box = CGRectMake(sf.x - bw * .5f, hy, bw, bh);
        CGContextStrokeRect(ctx, box);
    }
}
@end

// ── menu ──────────────────────────────────────────────────────────────────────
@interface CMenu : UIView
@property CGPoint dragOff;
@property (weak)   UIWindow *root;
@property (strong) UILabel  *espLbl;
@end

@implementation CMenu

- (instancetype)initIn:(UIWindow *)win {
    CGRect s = win.bounds;
    self = [super initWithFrame:CGRectMake(s.size.width/2 - kW/2,
                                           s.size.height * .14f, kW, kH)];
    if (!self) return nil;
    self.root               = win;
    self.backgroundColor    = kCOL_BG;
    self.layer.cornerRadius = 0;
    self.layer.masksToBounds = YES;
    self.layer.borderColor  = kCOL_BORDER.CGColor;
    self.layer.borderWidth  = .7f;
    [self buildHeader];
    [self buildBody];
    UIPanGestureRecognizer *p = [[UIPanGestureRecognizer alloc]
        initWithTarget:self action:@selector(onPan:)];
    [self addGestureRecognizer:p];
    return self;
}

// ── header ──────────────────────────────────────────────────────────────────
- (void)buildHeader {
    UIView *h = [[UIView alloc] initWithFrame:CGRectMake(0,0,kW,kHdr)];
    h.backgroundColor = kCOL_HDR;
    UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(0,kHdr-.5f,kW,.5f)];
    sep.backgroundColor = kCOL_BORDER;
    [h addSubview:sep];

    UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(8,0,kW-kBtn*2-14,kHdr)];
    t.text = @"Cheat iOS MODED | GAME";
    t.textColor = kCOL_ACC;
    t.font = [UIFont boldSystemFontOfSize:8.5f];
    t.adjustsFontSizeToFitWidth = YES;
    t.minimumScaleFactor = .7f;
    [h addSubview:t];

    UIButton *hb = [self mkHBtn:@"▬" x:kW-kBtn*2-6 sel:@selector(onHide)];
    UIButton *cb = [self mkHBtn:@"✕" x:kW-kBtn  -2 sel:@selector(onClose)];
    [h addSubview:hb]; [h addSubview:cb];
    [self addSubview:h];
}

- (UIButton *)mkHBtn:(NSString *)t x:(CGFloat)x sel:(SEL)s {
    UIButton *b = [[UIButton alloc] initWithFrame:
        CGRectMake(x, (kHdr-kBtn)/2, kBtn, kBtn)];
    b.backgroundColor = [UIColor colorWithWhite:.16f alpha:1];
    b.layer.cornerRadius = 0;
    b.titleLabel.font = [UIFont systemFontOfSize:9.f];
    [b setTitle:t forState:UIControlStateNormal];
    [b setTitleColor:kCOL_SUB forState:UIControlStateNormal];
    [b setTitleColor:UIColor.whiteColor forState:UIControlStateHighlighted];
    [b addTarget:self action:s forControlEvents:UIControlEventTouchUpInside];
    return b;
}

// ── body ────────────────────────────────────────────────────────────────────
- (void)buildBody {
    CGFloat y = kHdr + 8.f, p = 10.f, iw = kW - p*2;

    // section label
    UILabel *sec = [[UILabel alloc] initWithFrame:CGRectMake(p, y, iw, 14)];
    sec.text = @"VISUALS";
    sec.textColor = [UIColor colorWithWhite:.3f alpha:1];
    sec.font = [UIFont boldSystemFontOfSize:8.f];
    [self addSubview:sec]; y += 18.f;

    // ESP toggle row
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(p, y, iw, kRow)];
    row.backgroundColor = kCOL_ROW;
    row.userInteractionEnabled = YES;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(toggleESP)];
    [row addGestureRecognizer:tap];

    UILabel *rl = [[UILabel alloc] initWithFrame:CGRectMake(8,0,iw-60,kRow)];
    rl.text = @"Box ESP"; rl.textColor = UIColor.whiteColor;
    rl.font = [UIFont systemFontOfSize:11.f];
    [row addSubview:rl];

    UILabel *st = [[UILabel alloc] initWithFrame:CGRectMake(iw-52,(kRow-14)/2,44,14)];
    st.text = @"OFF"; st.textColor = [UIColor colorWithWhite:.4f alpha:1];
    st.font = [UIFont boldSystemFontOfSize:9.f];
    st.textAlignment = NSTextAlignmentRight;
    self.espLbl = st;
    [row addSubview:st];
    [self addSubview:row]; y += kRow + 6.f;

    // dist label
    UILabel *dl = [[UILabel alloc] initWithFrame:CGRectMake(p, y, iw, 14)];
    dl.text = [NSString stringWithFormat:@"ESP DIST  %.0fm", g_espDist];
    dl.textColor = kCOL_SUB; dl.font = [UIFont systemFontOfSize:9.f];
    dl.tag = 42;
    [self addSubview:dl]; y += 16.f;

    // slider
    UISlider *sl = [[UISlider alloc] initWithFrame:CGRectMake(p, y, iw, 22)];
    sl.minimumValue = 10; sl.maximumValue = 500; sl.value = g_espDist;
    sl.minimumTrackTintColor = kCOL_ACC;
    sl.maximumTrackTintColor = [UIColor colorWithWhite:.2f alpha:1];
    sl.thumbTintColor = UIColor.whiteColor;
    [sl addTarget:self action:@selector(onSlider:)
        forControlEvents:UIControlEventValueChanged];
    [self addSubview:sl];
}

- (void)toggleESP {
    g_espOn = !g_espOn;
    self.espLbl.text      = g_espOn ? @"ON"  : @"OFF";
    self.espLbl.textColor = g_espOn ? kCOL_ESP : [UIColor colorWithWhite:.4f alpha:1];
}

- (void)onSlider:(UISlider *)sl {
    g_espDist = sl.value;
    UILabel *l = (UILabel *)[self viewWithTag:42];
    l.text = [NSString stringWithFormat:@"ESP DIST  %.0fm", g_espDist];
}

// ── drag ────────────────────────────────────────────────────────────────────
- (void)onPan:(UIPanGestureRecognizer *)g {
    UIView *pv = self.superview; if (!pv) return;
    CGPoint loc = [g locationInView:pv];
    if (g.state == UIGestureRecognizerStateBegan)
        self.dragOff = CGPointMake(loc.x - self.frame.origin.x,
                                   loc.y - self.frame.origin.y);
    CGFloat nx = MAX(0, MIN(loc.x - self.dragOff.x, pv.bounds.size.width  - kW));
    CGFloat ny = MAX(0, MIN(loc.y - self.dragOff.y, pv.bounds.size.height - self.bounds.size.height));
    self.frame = CGRectMake(nx, ny, kW, self.bounds.size.height);
}

// ── hide ────────────────────────────────────────────────────────────────────
- (void)onHide {
    BOOL mini = self.bounds.size.height <= kHdr + 1;
    [UIView animateWithDuration:.15f animations:^{
        self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y,
                                kW, mini ? kH : kHdr);
    }];
}

// ── close ───────────────────────────────────────────────────────────────────
- (void)onClose {
    CGPoint pos = self.frame.origin;
    [self removeFromSuperview];
    UIButton *dot = [[UIButton alloc] initWithFrame:
        CGRectMake(MAX(4,pos.x), MAX(60,pos.y), 26, 26)];
    dot.backgroundColor = kCOL_ACC;
    dot.layer.borderColor = kCOL_BORDER.CGColor;
    dot.layer.borderWidth = .7f;
    dot.titleLabel.font = [UIFont boldSystemFontOfSize:10.f];
    [dot setTitle:@"C" forState:UIControlStateNormal];
    [dot setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    CMenu *__weak ws = self;
    [dot addTarget:ws action:@selector(onDotTap:) forControlEvents:UIControlEventTouchUpInside];
    [[UIPanGestureRecognizer alloc] initWithTarget:ws action:@selector(onDotPan:)];
    UIPanGestureRecognizer *dp = [[UIPanGestureRecognizer alloc]
        initWithTarget:ws action:@selector(onDotPan:)];
    [dot addGestureRecognizer:dp];
    [self.root addSubview:dot];
}
- (void)onDotTap:(UIButton *)dot {
    self.frame = CGRectMake(dot.frame.origin.x, dot.frame.origin.y, kW, kH);
    [dot removeFromSuperview];
    [self.root addSubview:self];
}
- (void)onDotPan:(UIPanGestureRecognizer *)g {
    UIView *dot = g.view, *pv = dot.superview; if (!pv) return;
    CGPoint loc = [g locationInView:pv];
    if (g.state == UIGestureRecognizerStateBegan)
        self.dragOff = CGPointMake(loc.x - dot.frame.origin.x,
                                   loc.y - dot.frame.origin.y);
    CGFloat nx = MAX(0, MIN(loc.x - self.dragOff.x, pv.bounds.size.width  - dot.bounds.size.width));
    CGFloat ny = MAX(60, MIN(loc.y - self.dragOff.y, pv.bounds.size.height - dot.bounds.size.height));
    dot.frame = CGRectMake(nx, ny, dot.bounds.size.width, dot.bounds.size.height);
}
@end

// ── tick ──────────────────────────────────────────────────────────────────────
static ESPView *gESP  = nil;
static CMenu   *gMenu = nil;

@interface CTick : NSObject + (void)tick:(CADisplayLink*)l; @end
@implementation CTick
+ (void)tick:(CADisplayLink*)l {
    if (!g_espOn) return;
    NSTimeInterval now = CACurrentMediaTime();
    if (now - g_lastUpd > 0.1) { g_lastUpd = now; refreshPlayers(); }
    [gESP setNeedsDisplay];
}
@end

// ── inject ────────────────────────────────────────────────────────────────────
__attribute__((constructor))
static void init(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        setupBridge();

        UIWindow *win = nil;
        for (UIScene *sc in UIApplication.sharedApplication.connectedScenes) {
            if (![sc isKindOfClass:[UIWindowScene class]]) continue;
            for (UIWindow *w in ((UIWindowScene *)sc).windows)
                if (w.isKeyWindow) { win = w; break; }
        }
        if (!win) win = UIApplication.sharedApplication.keyWindow;
        if (!win) return;

        gESP = [[ESPView alloc] initWithFrame:win.bounds];
        [win addSubview:gESP];

        gMenu = [[CMenu alloc] initIn:win];
        [win addSubview:gMenu];

        CADisplayLink *dl = [CADisplayLink displayLinkWithTarget:[CTick class]
                                                        selector:@selector(tick:)];
        dl.preferredFrameRateRange = CAFrameRateRangeMake(30, 60, 30);
        [dl addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    });
}
