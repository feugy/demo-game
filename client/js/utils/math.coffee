define [
], () ->

  {
    # Compute the location of the point C regarding the straight between A and B
    #
    # @param c [Object] tested point
    # @option c x [Number] C's abscissa
    # @option c y [Number] C's ordinate
    # @param a [Object] first reference point
    # @option a x [Number] A's abscissa
    # @option a y [Number] A's ordinate
    # @param b [Object] second reference point
    # @option b x [Number] B's abscissa
    # @option b y [Number] B's ordinate
    # @return true if C is above the straight formed by A and B
    isBelow: (c, a, b) ->
      # first the leading coefficient
      coef = (b.y - a.y) / (b.x - a.x)
      # second the straight equation: y = coeff*x + h
      h = a.y - coef*a.x
      # below if c.y is higher than the equation computation (because y is inverted)
      c.y > coef*c.x + h
  }