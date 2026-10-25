#import <UIKit/UIKit.h>

// ── config ────────────────────────────────────────────────────────────────────
static const CGFloat kW      = 210.f;
static const CGFloat kH      = 280.f;
static const CGFloat kHdr    = 34.f;
static const CGFloat kBtn    = 22.f;
static const CGFloat kRadius = 0.f;   // острые углы

#define kCOL_BG     [UIColor colorWithRed:.07f green:.07f blue:.08f alpha:1]
#define kCOL_HDR    [UIColor colorWithRed:.11f green:.11f blue:.13f alpha:1]
#define kCOL_ACC    [UIColor colorWithRed:.15f green:.55f blue:1.f  alpha:1]
#define kCOL_BORDER [UIColor colorWithWhite:.18f alpha:1]
#define kCOL_SUB    [UIColor colorWithWhite:.45f alpha:1]
// ─────────────────────────────────────────────────────────────────────────────

@interface CMenu : UIView
@property CGPoint dragOff;
@property (weak) UIWindow *root;
- (instancetype)initIn:(UIWindow *)win;
@end

@implementation CMenu

- (instancetype)initIn:(UIWindow *)win {
    CGRect s = win.bounds;
    self = [super initWithFrame:CGRectMake(s.size.width/2 - kW/2,
                                           s.size.height*.14f, kW, kH)];
    if (!self) return nil;
    self.root = win;
    self.backgroundColor        = kCOL_BG;
    self.layer.cornerRadius     = kRadius;
    self.layer.masksToBounds    = YES;
    self.layer.borderColor      = kCOL_BORDER.CGColor;
    self.layer.borderWidth      = .7f;

    [self addHeader];
    [self addBody];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
        initWithTarget:self action:@selector(onPan:)];
    [self addGestureRecognizer:pan];
    return self;
}

// ── header ────────────────────────────────────────────────────────────────────
- (void)addHeader {
    UIView *hdr = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kW, kHdr)];
    hdr.backgroundColor = kCOL_HDR;

    // separator line под header
    UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(0, kHdr - .5f, kW, .5f)];
    sep.backgroundColor = kCOL_BORDER;
    [hdr addSubview:sep];

    UILabel *title = [[UILabel alloc] initWithFrame:
        CGRectMake(8, 0, kW - kBtn*2 - 14, kHdr)];
    title.text          = @"Cheat iOS MODED | GAME";
    title.textColor     = kCOL_ACC;
    title.font          = [UIFont boldSystemFontOfSize:8.5f];
    title.adjustsFontSizeToFitWidth = YES;
    title.minimumScaleFactor = .7f;
    [hdr addSubview:title];

    UIButton *hideBtn  = [self headerBtn:@"▬" x:kW - kBtn*2 - 6];
    UIButton *closeBtn = [self headerBtn:@"✕" x:kW - kBtn  - 2];
    [hideBtn  addTarget:self action:@selector(onHide)  forControlEvents:UIControlEventTouchUpInside];
    [closeBtn addTarget:self action:@selector(onClose) forControlEvents:UIControlEventTouchUpInside];
    [hdr addSubview:hideBtn];
    [hdr addSubview:closeBtn];
    [self addSubview:hdr];
}

- (UIButton *)headerBtn:(NSString *)t x:(CGFloat)x {
    UIButton *b = [[UIButton alloc] initWithFrame:
        CGRectMake(x, (kHdr - kBtn)/2, kBtn, kBtn)];
    b.backgroundColor         = [UIColor colorWithWhite:.16f alpha:1];
    b.layer.cornerRadius      = 0;
    b.titleLabel.font         = [UIFont systemFontOfSize:9.f];
    [b setTitle:t forState:UIControlStateNormal];
    [b setTitleColor:kCOL_SUB   forState:UIControlStateNormal];
    [b setTitleColor:UIColor.whiteColor forState:UIControlStateHighlighted];
    return b;
}

// ── body ──────────────────────────────────────────────────────────────────────
- (void)addBody {
    UIView *body = [[UIView alloc] initWithFrame:
        CGRectMake(0, kHdr, kW, kH - kHdr)];
    body.backgroundColor = kCOL_BG;

    UILabel *ph = [[UILabel alloc] initWithFrame:
        CGRectMake(0, 0, kW, kH - kHdr)];
    ph.text          = @"— functions —";
    ph.textAlignment = NSTextAlignmentCenter;
    ph.textColor     = [UIColor colorWithWhite:.2f alpha:1];
    ph.font          = [UIFont systemFontOfSize:10.f];
    [body addSubview:ph];
    [self addSubview:body];
}

// ── drag ──────────────────────────────────────────────────────────────────────
- (void)onPan:(UIPanGestureRecognizer *)g {
    UIView *p = self.superview; if (!p) return;
    CGPoint loc = [g locationInView:p];
    if (g.state == UIGestureRecognizerStateBegan)
        self.dragOff = CGPointMake(loc.x - self.frame.origin.x,
                                   loc.y - self.frame.origin.y);
    CGFloat nx = MAX(0, MIN(loc.x - self.dragOff.x, p.bounds.size.width  - kW));
    CGFloat ny = MAX(0, MIN(loc.y - self.dragOff.y, p.bounds.size.height - self.bounds.size.height));
    self.frame = CGRectMake(nx, ny, kW, self.bounds.size.height);
}

// ── hide (свернуть в header) ──────────────────────────────────────────────────
- (void)onHide {
    BOOL mini = self.bounds.size.height <= kHdr + 1;
    [UIView animateWithDuration:.15f animations:^{
        self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y,
                                kW, mini ? kH : kHdr);
    }];
}

// ── close (убрать, оставить пиксель-кнопку) ──────────────────────────────────
- (void)onClose {
    CGPoint pos = self.frame.origin;
    [self removeFromSuperview];

    UIButton *dot = [[UIButton alloc] initWithFrame:
        CGRectMake(MAX(4, pos.x), MAX(60, pos.y), 26, 26)];
    dot.backgroundColor      = kCOL_ACC;
    dot.layer.cornerRadius   = 0;
    dot.layer.borderColor    = kCOL_BORDER.CGColor;
    dot.layer.borderWidth    = .7f;
    dot.titleLabel.font      = [UIFont boldSystemFontOfSize:10.f];
    [dot setTitle:@"C" forState:UIControlStateNormal];
    [dot setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    dot.tag = 9191;

    CMenu *__weak wself = self;
    [dot addTarget:wself action:@selector(onDotTap:) forControlEvents:UIControlEventTouchUpInside];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
        initWithTarget:wself action:@selector(onDotPan:)];
    [dot addGestureRecognizer:pan];
    [self.root addSubview:dot];
}

- (void)onDotTap:(UIButton *)dot {
    self.frame = CGRectMake(dot.frame.origin.x, dot.frame.origin.y, kW, kH);
    [dot removeFromSuperview];
    [self.root addSubview:self];
}

- (void)onDotPan:(UIPanGestureRecognizer *)g {
    UIView *dot = g.view, *p = dot.superview; if (!p) return;
    CGPoint loc = [g locationInView:p];
    if (g.state == UIGestureRecognizerStateBegan)
        self.dragOff = CGPointMake(loc.x - dot.frame.origin.x,
                                   loc.y - dot.frame.origin.y);
    CGFloat nx = MAX(0, MIN(loc.x - self.dragOff.x, p.bounds.size.width  - dot.bounds.size.width));
    CGFloat ny = MAX(60, MIN(loc.y - self.dragOff.y, p.bounds.size.height - dot.bounds.size.height));
    dot.frame = CGRectMake(nx, ny, dot.bounds.size.width, dot.bounds.size.height);
}

@end

// ── inject ────────────────────────────────────────────────────────────────────
static CMenu *gMenu = nil;

__attribute__((constructor))
static void init() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        UIWindow *win = nil;
        for (UIScene *sc in UIApplication.sharedApplication.connectedScenes) {
            if (![sc isKindOfClass:[UIWindowScene class]]) continue;
            for (UIWindow *w in ((UIWindowScene *)sc).windows)
                if (w.isKeyWindow) { win = w; break; }
        }
        if (!win) win = UIApplication.sharedApplication.keyWindow;
        if (!win) return;

        gMenu = [[CMenu alloc] initIn:win];
        [win addSubview:gMenu];
    });
}
