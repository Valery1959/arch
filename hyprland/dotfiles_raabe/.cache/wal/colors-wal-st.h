const char *colorname[] = {

  /* 8 normal colors */
  [0] = "#191210", /* black   */
  [1] = "#9D3824", /* red     */
  [2] = "#B34F2D", /* green   */
  [3] = "#D16230", /* yellow  */
  [4] = "#B07748", /* blue    */
  [5] = "#688469", /* magenta */
  [6] = "#A79261", /* cyan    */
  [7] = "#e5c6a0", /* white   */

  /* 8 bright colors */
  [8]  = "#a08a70",  /* black   */
  [9]  = "#9D3824",  /* red     */
  [10] = "#B34F2D", /* green   */
  [11] = "#D16230", /* yellow  */
  [12] = "#B07748", /* blue    */
  [13] = "#688469", /* magenta */
  [14] = "#A79261", /* cyan    */
  [15] = "#e5c6a0", /* white   */

  /* special colors */
  [256] = "#191210", /* background */
  [257] = "#e5c6a0", /* foreground */
  [258] = "#e5c6a0",     /* cursor */
};

/* Default colors (colorname index)
 * foreground, background, cursor */
 unsigned int defaultbg = 0;
 unsigned int defaultfg = 257;
 unsigned int defaultcs = 258;
 unsigned int defaultrcs= 258;
