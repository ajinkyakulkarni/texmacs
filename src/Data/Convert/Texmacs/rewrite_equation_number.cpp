
/******************************************************************************
* MODULE     : rewrite_equation_number.cpp
* DESCRIPTION: Conversion eqnumber <-> nonumber
* COPYRIGHT  : (C) 2013 François Poulain, Joris van der Hoeven
*******************************************************************************
* This software falls under the GNU general public license version 3 or later.
* It comes WITHOUT ANY WARRANTY WHATSOEVER. For details, see the file LICENSE
* in the root directory or <http://www.gnu.org/licenses/gpl-3.0.html>.
******************************************************************************/

#include "tree.hpp"
#include "string.hpp"
#include "convert.hpp"

#define cmp compound
#define is_cmp is_compound

static tree
replace_subtree (tree t, tree from, tree to) {
  if (t == from) return to;
  if (is_atomic (t)) return t;
  tree r(L(t));
  for (int i=0; i<N(t); i++)
    r << replace_subtree (t[i], from, to);
  return r;
}

static bool
contains_subtree (tree t, tree st) {
  if (t == st) return true;
  if (is_atomic (t)) return false;
  for (int i=0; i<N(t); i++)
    if (contains_subtree (t[i], st))
      return true;
  return false;
}

static tree
find_equation_label (tree t) {
  if (is_cmp (t, "label")) return t;
  if (is_atomic (t)) return concat();
  tree r;
  for (int i=N(t)-1; i>=0; i--) {
    r= find_equation_label (t[i]);
    if (!is_concat (r))
      break;
  }
  return r;
}

static tree
add_eqnonumber (tree t, tree add) {
  if (is_cmp (t, "row")) {
    if (N(t) == 0) return tree (CELL, add);
    tree lab= find_equation_label (t);
    if (is_cmp (lab, "label") && add == cmp ("eq-number")) {
      t= replace_subtree (t, lab, "");
      add= concat (add, lab);
    }
    t[N(t)-1]= add_eqnonumber (t[N(t)-1], add);
    return t;
  }
  else if (is_cmp (t, "cell", 1))
    return tree (CELL, add_eqnonumber (t[0], add));
  else
    return concat (t, add);
}

static tree
rewrite_in_tables (tree t, tree from, tree to) {
  if (is_cmp (t, "document") || is_cmp (t, "tformat") || is_cmp (t, "table")) {
    tree r(L(t));
    for (int i=0; i<N(t); i++)
      r << rewrite_in_tables (t[i], from, to);
    return r;
  }
  else if (is_cmp (t, "row")) {
    if (contains_subtree (t, from))
      return replace_subtree (t, from, "");
    else
      return add_eqnonumber (t, to);
  }
  else
    return t;
}

tree
rewrite_equation_number (tree t, tree from, tree to) {
  // FIXME: extend to amsmath environments
  if (is_atomic (t))
    return t;
  else if (is_cmp (t, "eqnarray*") && !contains_subtree (t, from))
    return t;
  else if (is_cmp (t, "eqnarray*") || is_cmp (t, "eqnarray")) {
    tree r= cmp ("eqnarray");
    for (int i=0; i<N(t); i++)
      r << rewrite_in_tables (t[i], from, to);
    return r;
  }
  else {
    tree r(L(t));
    for (int i=0; i<N(t); i++)
      r << rewrite_equation_number (t[i], from, to);
    return r;
  }
}

tree
eqnumber_to_nonumber (tree t) {
  return rewrite_equation_number (t, cmp ("eq-number"), cmp ("no-number"));
}

tree
nonumber_to_eqnumber (tree t) {
  return rewrite_equation_number (t, cmp ("no-number"), cmp ("eq-number"));
}

#undef cmp
#undef is_cmp
