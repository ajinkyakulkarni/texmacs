
/******************************************************************************
* MODULE     : curve.hpp
* DESCRIPTION: mathematical curves
* COPYRIGHT  : (C) 2003  Joris van der Hoeven
*******************************************************************************
* This software falls under the GNU general public license and comes WITHOUT
* ANY WARRANTY WHATSOEVER. See the file $TEXMACS_PATH/LICENSE for more details.
* If you don't have this file, write to the Free Software Foundation, Inc.,
* 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
******************************************************************************/

#ifndef CURVE_H
#define CURVE_H
#include "point.hpp"

class curve_rep: public abstract_struct {
public:
  inline curve_rep () {}
  inline virtual ~curve_rep () {}

  inline virtual int nr_components () { return 1; }
  // the number of components of the curve is useful for getting
  // nice parameterizations when concatenating curves

  virtual point evaluate (double t) = 0;
  // gives a point on the curve for its intrinsic parameterization
  // curves are parameterized from 0.0 to 1.0

  array<point> rectify (double err);
  // returns a rectification of the curve, which, modulo reparameterization
  // has a uniform distance of at most 'err' to the original curve

  virtual void rectify_cumul (array<point>& a, double err) = 0;
  // add rectification of the curve  (except for the staring point)
  // to an existing polysegment

  /* NOTE: more routines should be added later so that one
     can reliably compute the intersections between curves */
};

class curve {
  ABSTRACT_NULL(curve);
  curve (point p1, point p2); // straight curve
  inline point operator () (double t) { return rep->evaluate (t); }
  inline bool operator == (curve c) { return rep == c.rep; }
  inline bool operator != (curve c) { return rep != c.rep; }
};
ABSTRACT_NULL_CODE(curve);

curve operator * (curve c1, curve c2);
curve invert (curve c);

#endif // defined CURVE_H
