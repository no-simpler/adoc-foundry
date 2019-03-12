// A trigger which is queried by render-math.js in PhantomJS
var MathJaxFinished = false;

// This function will be called when MathJax has finished *all* rendering
MathJax.Hub.Queue(
    function () {
        MathJaxFinished = true;
    }
);

// A sample MathJax setup for HTML-CSS
MathJax.Hub.Config({
  // displayAlign: "left",
  // displayIndent: "3em",
  extensions: ["tex2jax.js"],
  // Tex input, HTML-CSS output
  jax: ["input/TeX", "output/HTML-CSS"],
  imageFont: null,
  messageStyle: "none",
  showProcessingMessages: false,
  showMathMenu: false,
  delayStartupUntil: "onload",
  tex2jax: {
    ignoreClass: "tex2jax_ignore",
    processClass: "math",
    inlineMath: [ ["$","$"], ["\\(","\\)"] ],
    displayMath: [ ["$$","$$"], ["\\[","\\]"] ],
    processEscapes: false,
    preview: "none"
  },
  TeX: {
    extensions: ["AMSmath.js","AMSsymbols.js", "color.js"],
    // TagSide: "left",
    // TagIndent: "0em",
    MultLineWidth: "85%",
    // equationNumbers: {
    //   autoNumber: "AMS"
    // },
    unicode: {
      fonts: "STIXGeneral,'Arial Unicode MS'"
    }
  },
  "HTML-CSS": {
      scale: 100,
      minScaleAdjust: 50,
      linebreaks: {
          automatic: true
      },
      // Anchors in formulas in black
      styles: {
        ".MathJax a": {
          color: "#000000"
        },
        ".MathJax": {
          "vertical-align": "baseline"
        }
      },
      mtextFontInherit: true,
      matchFontHeight: true,
      availableFonts: ["TeX"],
      preferredFont: "TeX",
      webFont: "TeX",
      imageFont: null
  }
});