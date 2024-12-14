static const char norm_fg[] = "#e5c6a0";
static const char norm_bg[] = "#191210";
static const char norm_border[] = "#a08a70";

static const char sel_fg[] = "#e5c6a0";
static const char sel_bg[] = "#B34F2D";
static const char sel_border[] = "#e5c6a0";

static const char urg_fg[] = "#e5c6a0";
static const char urg_bg[] = "#9D3824";
static const char urg_border[] = "#9D3824";

static const char *colors[][3]      = {
    /*               fg           bg         border                         */
    [SchemeNorm] = { norm_fg,     norm_bg,   norm_border }, // unfocused wins
    [SchemeSel]  = { sel_fg,      sel_bg,    sel_border },  // the focused win
    [SchemeUrg] =  { urg_fg,      urg_bg,    urg_border },
};
