<TeXmacs|1.0.3.4>

<style|source>

<\body>
  <\active*>
    <\src-title>
      <src-style-file|tmdoc|1.0>

      <\src-purpose>
        Style for the <TeXmacs> manual(s).
      </src-purpose>

      <\src-copyright|2002--2004>
        Joris van der Hoeven
      </src-copyright>

      <\src-license>
        This <TeXmacs> style file falls under the <hlink|GNU general public
        license|$TEXMACS_PATH/LICENSE> and comes WITHOUT ANY WARRANTY
        WHATSOEVER. If you don't have this file, then write to the Free
        Software Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
        02111-1307, USA.
      </src-license>
    </src-title>
  </active*>

  <use-package|tmbook|tmdoc-markup|tmdoc-keyboard|tmdoc-traversal>

  \;

  <assign|par-hyphen|professional>

  <assign|par-par-sep|0.5fn>

  <assign|par-first|0fn>

  <assign|font-base-size|11>

  \;

  <assign|title*|<\macro|name>
    <style-with|src-compact|none|<assign|page-this-header|><assign|page-this-footer|><vspace|0.33pag>>

    <style-with|src-compact|none|<no-indent><with|math-font-series|bold|font-series|bold|font-shape|small-caps|font-size|2|<style-with|src-compact|none|<htab|0fn><arg|name><htab|0fn>>><new-page>>

    <style-with|src-compact|none|<assign|page-this-header|><assign|page-this-footer|><vspace|0.33pag>>

    <new-page>
  </macro>>

  <assign|title|<macro|body|<title*|<arg|body>>>>

  \;
</body>

<\initial>
  <\collection>
    <associate|language|english>
    <associate|page-bot|30mm>
    <associate|page-even|30mm>
    <associate|page-odd|30mm>
    <associate|page-reduce-bot|15mm>
    <associate|page-reduce-left|25mm>
    <associate|page-reduce-right|25mm>
    <associate|page-reduce-top|15mm>
    <associate|page-right|30mm>
    <associate|page-top|30mm>
    <associate|page-type|a4>
    <associate|par-width|150mm>
    <associate|preamble|true>
    <associate|sfactor|5>
  </collection>
</initial>