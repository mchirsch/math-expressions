part of math_expressions;

/**
 * A function with an arbitrary number of arguments.
 *
 * __Note:__ Functions do not offer auto-wrapping of arguments into [Literal]s.
 */
abstract class MathFunction extends Expression {
  /// Name of this function.
  String name;

  /// List of arguments of this function. Arguments ust be of type [Variable].
  List<Variable> args;

  // TODO
  // isComplete() => all bound?

  /**
   * Creates a new function with the given name and arguments.
   */
  MathFunction(this.name, this.args);

  /**
   * Creates a new function with the given name.
   *
   * __Note__:
   * Must only be used internally by subclasses, as it does not define any
   * arguments.
   */
  MathFunction._empty(this.name);

  /// Compose operator. Creates a [CompositeFunction].
  MathFunction operator &(MathFunction g) => new CompositeFunction(this, g);

  /**
   * Returns the i-th parameter of this function (0-based).
   */
  Variable getParam(int i) => args[i];

  /**
   * Returns the parameter with the given name.
   */
  Variable getParamByName(String name) =>
      args.singleWhere((e) => e.name == name);

  /// The dimension of the domain of definition of this function.
  int get domainDimension => args.length;

  @override
  String toString() => '$name($args)';

  /**
   * Returns the full string representation of this function.
   * This could include the name, variables and expression.
   *
   * Any subclass should decide whether to override this method.
   */
  String toFullString() => toString();
}

/**
 * A composition of two given [MathFunction]s.
 */
//TODO: How to infer evaluator types? How to infer domain and range? How to check compatibility?
//      Allow composites which are not complete and create new functions?
//      -> Add more information on expected behaviour to MathFunctions? Better matching!
//      -> What if functions are overloaded and can operate on several types? Duplicate functions..
class CompositeFunction extends MathFunction {
  /// Members `f` and `g` of the composite function.
  MathFunction f, g;

  /**
   * Creates a function composition.
   *
   * For example, given `f(x): R -> R^3` and `g(x,y,z): R^3 -> R`
   * the composition yields `(g ?? f)(x): R -> R^3 -> R`. First
   * `f` is applied, then `g` is applied.
   *
   * Given some requirements
   *     x = new Variable('x');
   *     xPlus = new Plus(x, 1);
   *     xMinus = new Minus(x, 1);
   *
   *     fExpr = new Vector([x, xPlus, xMinus]);        // Transforms x to 3-dimensional vector
   *     f = new CustomFunction('f', [x], fExpr);       // Creates a function R -> R^3 from fExpr
   *
   *     y = new Variable('z');
   *     z = new Variable('y');
   *
   *     gExpr = x + y + z;                             // Transforms 3-dimensional input to real value
   *     g = new CustomFunction('g', [x, y, z], gExpr)  // Creates a function R^3 -> R from gExpr
   *
   * a composition can be created as follows:
   *     composite = new CompositeFunction(f, g); // R -> R
   *                                              // composite(2) = 6
   */
  CompositeFunction(this.f, this.g)
      : super('comp(${f.name},${g.name})', f.args);

  /// The domain of the 'second' function, which should match the range
  /// of the 'first function.
  int get gDomainDimension => g.domainDimension;

  /// The domain of the 'first' function.
  @override
  int get domainDimension => f.domainDimension;

  @override
  Expression derive(String toVar) {
    MathFunction gDF;
    final Expression gD = g.derive(toVar);

    if (!(gD is MathFunction)) {
      // Build function again..
      gDF = new CustomFunction('d${g.name}', g.args, gD);
    } else {
      gDF = gD;
    }

    // Chain rule.
    return new CompositeFunction(f, gDF) * f.derive(toVar);
  }

  /**
   * Simplifies both component functions.
   */
  @override
  Expression simplify() {
    final MathFunction fSimpl = f.simplify();
    final MathFunction gSimpl = g.simplify();

    return new CompositeFunction(fSimpl, gSimpl);
  }

  /**
   * The EvaluationType of `f` is detected automatically based on
   * the domain dimension of `g`. This is because the input of
   * `g` is the output of `f` (composite function).
   *
   * The given EvaluationType is used for `g` because there is no
   * information on the expected output.
   *
   * Furthermore `g` is assigned a separate child scope of the given
   * `context`, so that variable naming does not interfer with the
   * evaluation.
   */
  @override
  dynamic evaluate(EvaluationType type, ContextModel context) {
    //TODO - Check if necessary variables have been bound to context.
    //     - Type checks.
    dynamic fEval;
    final ContextModel childScope = context.createChildScope();

    // We expect result to be of dimension gDomainDimension.
    if (gDomainDimension == 1) {
      // Expect f to evaluate to a real.
      fEval = f.evaluate(EvaluationType.REAL, context);
      // Create new context and bind (single) input of g to fEval.
      childScope.bindVariable(g.getParam(0), _toExpression(fEval));
      return g.evaluate(type, childScope);
    }

    if (gDomainDimension == 2) {
      // Expect f to evaluate to a 2-dimensional vector.
      fEval = f.evaluate(EvaluationType.VECTOR, context);
      childScope
        ..bindVariable(g.getParam(0), _toExpression(fEval.x))
        ..bindVariable(g.getParam(1), _toExpression(fEval.y));
      return g.evaluate(type, childScope);
    }

    if (gDomainDimension == 3) {
      // Expect f to evaluate to a 3-dimensional vector.
      fEval = f.evaluate(EvaluationType.VECTOR, context);
      childScope
        ..bindVariable(g.getParam(0), _toExpression(fEval.x))
        ..bindVariable(g.getParam(1), _toExpression(fEval.y))
        ..bindVariable(g.getParam(2), _toExpression(fEval.z));
      return g.evaluate(type, childScope);
    }

    if (gDomainDimension == 4) {
      // Expect f to evaluate to a 4-dimensional vector.
      fEval = f.evaluate(EvaluationType.VECTOR, context);
      childScope
        ..bindVariable(g.getParam(0), _toExpression(fEval.x))
        ..bindVariable(g.getParam(1), _toExpression(fEval.y))
        ..bindVariable(g.getParam(2), _toExpression(fEval.z))
        ..bindVariable(g.getParam(3), _toExpression(fEval.w));
      return g.evaluate(type, childScope);
    }

    //TODO Handle arbitrary vectors.
    throw new UnimplementedError('Vectors > 4 not supported yet.');
  }
}

/**
 * Any user-created function is a CustomFunction.
 */
//TODO Interpret as Function call instead?
class CustomFunction extends MathFunction {
  /// Function expression of this function.
  /// Used for non-default or user-defined functions.
  Expression expression;

  /**
   * Create a custom function with the given name, argument variables,
   * and expression.
   */
  CustomFunction(String name, List<Variable> args, this.expression)
      : super(name, args);

  @override
  Expression derive(String toVar) =>
      new CustomFunction(name, args, expression.derive(toVar));

  @override
  Expression simplify() =>
      new CustomFunction(name, args, expression.simplify());

  // TODO: Substitute external variables?
  //       => Shouldn't be necessary as context model is handed over.
  //          (FL 2013-11-08)
  @override
  dynamic evaluate(EvaluationType type, ContextModel context) =>
      // TODO: First check if all necessary variables are bound.
      //       => Not necessary with current system, has to be handled by calling
      //          instance (throws unbound variable exception).
      //          (FL 2013-11-08)
      expression.evaluate(type, context);

  @override
  String toFullString() => '$name($args) = $expression';
}

class FunctionCall extends Literal {
  /**
   * Create a custom function with the given name, argument variables,
   * and expression.
   */
  FunctionCall(String name) : super(name);

  @override
  Expression derive(String toVar) =>
      throw new UnsupportedError('Can not differentiate FunctionCall');

  @override
  dynamic evaluate(EvaluationType type, ContextModel context) =>
      context.getFunction(this.value).evaluate(type, context.createChildScope());

}

/**
 * A default function is predefined in this library.
 * It contains no expression because the appropriate evaluation method usually
 * uses native Dart math code.
 *
 * __Note__:
 * User-defined custom functions should derive from [CustomFunction], which
 * supports arbitrary expressions.
 */
abstract class DefaultFunction extends MathFunction {
  /**
   * Creates a new unary function with given name and argument.
   * If the argument is not a variable, it will be wrapped into an anonymous
   * variable, which binds the given expression.
   *
   * __Note__:
   * Must only be used internally for pre-defined functions, as it does not
   * contain any expression. The Evaluator needs to know how to handle this.
   */
  DefaultFunction._unary(String name, Expression arg) : super._empty(name) {
    final Variable bindingVariable = _wrapIntoVariable(arg);
    this.args = <Variable>[bindingVariable];
  }

  /**
   * Creates a new binary function with given name and two arguments.
   * If the arguments are not variables, they will be wrapped into anonymous
   * variables, which bind the given expressions.
   *
   * __Note__:
   * Must only be used internally for pre-defined functions, as it does not
   * contain any expression. The Evaluator needs to know how to handle this.
   */
  DefaultFunction._binary(String name, Expression arg1, Expression arg2)
      : super._empty(name) {
    final Variable bindingVariable1 = _wrapIntoVariable(arg1);
    final Variable bindingVariable2 = _wrapIntoVariable(arg2);
    this.args = <Variable>[bindingVariable1, bindingVariable2];
  }

  /**
   * Returns a variable, bound to the given [Expression].
   * Returns the parameter itself, if it is already a variable.
   */
  Variable _wrapIntoVariable(Expression e) {
    if (e is Variable) {
      // Good to go..
      return e;
    } else {
      // Need to wrap..
      return new BoundVariable(e);
    }
  }

  @override
  String toString() =>
      args.length == 1 ? '$name(${args[0]})' : '$name(${args[0]},${args[1]})';
}

/**
 * The exponential function.
 */
class Exponential extends DefaultFunction {
  /**
   * Creates a exponential operation on the given expressions.
   *
   * For example, to create e^4:
   *     four = new Number(4);
   *     exp = new Exponential(four);
   *
   * You also can use variables or arbitrary expressions:
   *     x = new Variable('x');
   *     exp = new Exponential(x);
   *     exp = new Exponential(x + four);
   */
  Exponential(Expression exp) : super._unary('exp', exp);

  /// The exponent of this exponential function.
  Expression get exp => getParam(0);

  @override
  Expression derive(String toVar) => new Times(this, exp.derive(toVar));

  /**
   * Possible simplifications:
   *
   * 1. e^0 = 1
   * 2. e^1 = e
   * 3. e^(x*ln(y)) = y^x (usually easier to read for humans)
   */
  @override
  Expression simplify() {
    final Expression expSimpl = exp.simplify();

    if (_isNumber(expSimpl, 0)) {
      return new Number(1); // e^0 = 1
    }

    if (_isNumber(expSimpl, 1)) {
      return new Number(math.e); // e^1 = e
    }

    if (expSimpl is Times && expSimpl.second is Ln) {
      final Ln ln = expSimpl.second;
      return new Power(ln.arg, expSimpl.first); // e^(x*ln(y)) = y^x
    }

    return new Exponential(expSimpl);
  }

  @override
  dynamic evaluate(EvaluationType type, ContextModel context) {
    final dynamic expEval = exp.evaluate(type, context);

    if (type == EvaluationType.REAL) {
      // Expect exponent to be real number.
      return math.exp(expEval);
    }

    if (type == EvaluationType.INTERVAL) {
      // Special case of a^[x, y] = [a^x, a^y] for a > 1 (with a = e)
      // Expect exponent to be interval.
      return new Interval(math.exp(expEval.min), math.exp(expEval.max));
    }

    throw new UnimplementedError('Can not evaluate $name on $type yet.');
  }
}

/**
 * The logarithm function.
 */
class Log extends DefaultFunction {
  /**
   * Creates a logarithm function with given base and argument.
   *
   * For example, to create log_10(2):
   *     base = new Number(10);
   *     arg = new Number(2);
   *     log = new Log(base, arg);
   *
   * To create a naturally based logarithm, see [Ln].
   */
  Log(Expression base, Expression arg) : super._binary('log', base, arg);

  /**
   * Creates a natural logarithm.
   * Must only be used internally by the Ln class.
   */
  Log._ln(Expression arg) : super._binary('ln', new Number(math.e), arg);

  /// The base of this logarithm.
  Expression get base => getParam(0);

  /// The argument of this logarithm.
  Expression get arg => getParam(1);

  @override
  Expression derive(String toVar) => this.asNaturalLogarithm().derive(toVar);

  /**
   * Simplifies base and argument.
   */
  @override
  Expression simplify() => new Log(base.simplify(), arg.simplify());

  @override
  dynamic evaluate(EvaluationType type, ContextModel context) {
    if (type == EvaluationType.REAL) {
      // Be lazy, convert to Ln.
      return asNaturalLogarithm().evaluate(type, context);
    }

    if (type == EvaluationType.INTERVAL) {
      // log_a([x, y]) = [log_a(x), log_a(y)] for [x, y] positive and a > 1
      return asNaturalLogarithm().evaluate(type, context);
    }

    throw new UnimplementedError('Can not evaluate $name on $type yet.');
  }

  @override
  String toString() => 'log_$base($arg)';

  /**
   * Returns the natural from of this logarithm.
   * E.g. log_10(2) = ln(2) / ln(10)
   *
   * This method is used to determine the derivation of a logarithmic
   * expression.
   */
  Expression asNaturalLogarithm() => new Ln(arg) / new Ln(base);
}

/**
 * The natural logarithm (log based e).
 */
class Ln extends Log {
  /**
   * Creates a natural logarithm function with given argument.
   *
   * For example, to create ln(10):
   *     num10 = new Number(10);
   *     ln = new Ln(num10);
   *
   * To create a logarithm with arbitrary base, see [Log].
   */
  Ln(Expression arg) : super._ln(arg);

  @override
  Expression derive(String toVar) => arg.derive(toVar) / arg;

  /**
   * Possible simplifications:
   *
   * 1. ln(1) = 0
   */
  @override
  Expression simplify() {
    final Expression argSimpl = arg.simplify();

    if (_isNumber(argSimpl, 1)) {
      return new Number(0); // ln(1) = 0
    }

    return new Ln(argSimpl);
  }

  @override
  dynamic evaluate(EvaluationType type, ContextModel context) {
    final dynamic argEval = arg.evaluate(type, context);

    if (type == EvaluationType.REAL) {
      return math.log(argEval);
    }

    if (type == EvaluationType.INTERVAL) {
      // Expect argument of type interval
      return new Interval(math.log(argEval.min), math.log(argEval.max));
    }

    throw new UnimplementedError('Can not evaluate $name on $type yet.');
  }

  @override
  String toString() => 'ln($arg)';
}

/**
 * The n-th root function. n needs to be a natural number.
 *
 * TODO: Allow n to be an expression?
 */
class Root extends DefaultFunction {
  /// N-th root.
  int n;

  /**
   * Creates the n-th root of arg.
   *
   * For example, to create the 5th root of x:
   *     root = new Root(5, new Variable('x'));
   */
  Root(this.n, Expression arg) : super._unary('root', arg);

  /**
   * Creates the n-th root of arg where n is a [Number] literal.
   */
  Root.fromExpr(Number n, Expression arg) : super._unary('root', arg) {
    this.n = n.getConstantValue().toInt();
  }

  /**
   * Creates the square root of arg.
   *
   * For example, to create the square root of x:
   *     sqrt = new Root.sqrt(new Variable('x'));
   *
   * __Note__:
   * For better simplification and display, use the [Sqrt] class.
   */
  Root.sqrt(Expression arg)
      : n = 2,
        super._unary('sqrt', arg);

  Expression get arg => getParam(0);

  @override
  Expression derive(String toVar) => this.asPower().derive(toVar);

  /**
   * Simplify argument.
   */
  @override
  Expression simplify() => new Root(n, arg.simplify());

  @override
  dynamic evaluate(EvaluationType type, ContextModel context) =>
      this.asPower().evaluate(type, context);

  @override
  String toString() => 'nrt_$n($arg)';

  /**
   * Returns the power form of this root.
   * E.g. root_5(x) = x^(1/5)
   *
   * This method is used to determine the derivation of a root
   * expression.
   */
  Expression asPower() =>
      new Power(arg, new Divide(new Number(1), new Number(n)));
}

/**
 * The square root function.
 */
class Sqrt extends Root {
  /**
   * Creates the square root of arg.
   *
   * For example, to create the square root of x:
   *     sqrt = new Sqrt(new Variable('x'));
   */
  Sqrt(Expression arg) : super.sqrt(arg);

  /**
   * Possible simplifications:
   *
   * 1. sqrt(x^2) = x
   * 2. sqrt(0) = 0
   * 3. sqrt(1) = 1
   *
   * __Note__:
   * This simplification works _only_ for real numbers and _not_ for complex
   * numbers.
   */
  @override
  Expression simplify() {
    final Expression argSimpl = arg.simplify();

    if (argSimpl is Power) {
      final Expression exponent = argSimpl.second;
      if (exponent is Number) {
        if (exponent.value == 2) {
          return argSimpl.first; // sqrt(x^2) = x
        }
      }
    }

    if (_isNumber(argSimpl, 0)) {
      return new Number(0); // sqrt(0) = 0
    }

    if (_isNumber(argSimpl, 1)) {
      return new Number(1); // sqrt(1) = 1
    }

    return new Sqrt(argSimpl);
  }

  @override
  dynamic evaluate(EvaluationType type, ContextModel context) {
    final dynamic argEval = arg.evaluate(type, context);

    if (type == EvaluationType.REAL) {
      return math.sqrt(argEval);
    }

    if (type == EvaluationType.VECTOR) {
      //TODO apply function to all vector elements
    }

    if (type == EvaluationType.INTERVAL) {
      // Piecewiese sqrting.
      return new Interval(math.sqrt(argEval.min), math.sqrt(argEval.max));
    }

    throw new UnimplementedError('Can not evaluate $name on $type yet.');
  }

  @override
  String toString() => 'sqrt($arg)';
}

/**
 * The sine function.
 */
class Sin extends DefaultFunction {
  /**
   * Creates a new sine function with given argument expression.
   */
  Sin(Expression arg) : super._unary('sin', arg);

  /// The argument of this sine function.
  Expression get arg => getParam(0);

  @override
  Expression derive(String toVar) => new Cos(arg) * arg.derive(toVar);

  /**
   * Possible simplifications:
   *
   * 1. sin(0) = 0
   */
  @override
  Expression simplify() {
    final Expression argSimpl = arg.simplify();

    if (_isNumber(argSimpl, 0)) {
      return new Number(0); // sin(0) = 0
    }

    return new Sin(argSimpl);
  }

  @override
  dynamic evaluate(EvaluationType type, ContextModel context) {
    final dynamic argEval = arg.evaluate(type, context);

    if (type == EvaluationType.REAL) {
      return math.sin(argEval);
    }

    if (type == EvaluationType.VECTOR) {
      //TODO Apply function to all vector elements
    }

    if (type == EvaluationType.INTERVAL) {
      // TODO evaluate endpoints and critical points ((1/2 + n) * pi)
      // or just return [-1, 1] if half a period is in the given interval
    }

    throw new UnimplementedError('Can not evaluate $name on $type yet.');
  }
}

/**
 * The cosine function.
 */
class Cos extends DefaultFunction {
  /**
   * Creates a new cosine function with given argument expression.
   */
  Cos(Expression arg) : super._unary('cos', arg);

  /// The argument of this cosine function.
  Expression get arg => getParam(0);

  @override
  Expression derive(String toVar) => -new Sin(arg) * arg.derive(toVar);

  /**
   * Possible simplifications:
   *
   * 1. cos(0) = 1
   */
  @override
  Expression simplify() {
    final Expression argSimpl = arg.simplify();

    if (_isNumber(argSimpl, 0)) {
      return new Number(1); // cos(0) = 1
    }

    return new Cos(argSimpl);
  }

  @override
  dynamic evaluate(EvaluationType type, ContextModel context) {
    final dynamic argEval = arg.evaluate(type, context);

    if (type == EvaluationType.REAL) {
      return math.cos(argEval);
    }

    if (type == EvaluationType.VECTOR) {
      //TODO apply function to all vector elements
    }

    if (type == EvaluationType.INTERVAL) {
      // TODO evaluate endpoints and critical points (n * pi)
      // or just return [-1, 1] if half a period is in the given interval
    }

    throw new UnimplementedError('Can not evaluate $name on $type yet.');
  }
}

/**
 * The tangens function.
 */
class Tan extends DefaultFunction {
  /**
   * Creates a new tangens function with given argument expression.
   */
  Tan(Expression arg) : super._unary('tan', arg);

  /// The argument of this tangens function.
  Expression get arg => getParam(0);

  @override
  Expression derive(String toVar) => asSinCos().derive(toVar);

  /**
   * Possible simplifications:
   *
   * 1. tan(0) = 0
   */
  @override
  Expression simplify() {
    final Expression argSimpl = arg.simplify();

    if (_isNumber(argSimpl, 0)) {
      return new Number(0); // tan(0) = 0
    }

    return new Tan(argSimpl);
  }

  @override
  dynamic evaluate(EvaluationType type, ContextModel context) {
    final dynamic argEval = arg.evaluate(type, context);

    if (type == EvaluationType.REAL) {
      return math.tan(argEval);
    }

    if (type == EvaluationType.VECTOR) {
      //TODO apply function to all vector elements
    }

    throw new UnimplementedError('Can not evaluate $name on $type yet.');
  }

  /**
   * Returns this tangens as sine and cosine representation.
   *
   * `tan(x) = sin(x) / cos(x)`
   */
  Expression asSinCos() => new Sin(arg) / new Cos(arg);
}

/**
 * The arcus sine function.
 */
class Asin extends DefaultFunction {
  /**
   * Creates a new arcus sine function with given argument expression.
   */
  Asin(Expression arg) : super._unary('arcsin', arg);

  /// The argument of this arcus sine function.
  Expression get arg => getParam(0);

  @override
  Expression derive(String toVar) =>
      new Number(1) / new Sqrt(new Number(1) - (arg ^ new Number(2)));

  /**
   * Possible simplifications:
   */
  @override
  Expression simplify() {
    return new Asin(arg.simplify());
  }

  @override
  dynamic evaluate(EvaluationType type, ContextModel context) {
    final dynamic argEval = arg.evaluate(type, context);

    if (type == EvaluationType.REAL) {
      return math.asin(argEval);
    }

    // TODO VECTOR and INTERVAL evaluation
    throw new UnimplementedError('Can not evaluate $name on $type yet.');
  }
}

/**
 * The arcus cosine function.
 */
class Acos extends DefaultFunction {
  /**
   * Creates a new arcus cosine function with given argument expression.
   */
  Acos(Expression arg) : super._unary('arccos', arg);

  /// The argument of this arcus cosine function.
  Expression get arg => getParam(0);

  @override
  Expression derive(String toVar) =>
      -new Number(1) / new Sqrt(new Number(1) - (arg ^ new Number(2)));

  /**
   * Possible simplifications:
   */
  @override
  Expression simplify() {
    return new Acos(arg.simplify());
  }

  @override
  dynamic evaluate(EvaluationType type, ContextModel context) {
    final dynamic argEval = arg.evaluate(type, context);

    if (type == EvaluationType.REAL) {
      return math.acos(argEval);
    }

    // TODO VECTOR and INTERVAL evaluation
    throw new UnimplementedError('Can not evaluate $name on $type yet.');
  }
}

/**
 * The arcus tangens function.
 */
class Atan extends DefaultFunction {
  /**
   * Creates a new arcus tangens function with given argument expression.
   */
  Atan(Expression arg) : super._unary('arctan', arg);

  /// The argument of this arcus tangens function.
  Expression get arg => getParam(0);

  @override
  Expression derive(String toVar) =>
      new Number(1) / (new Number(1) + (arg ^ new Number(2)));

  /**
   * Possible simplifications:
   */
  @override
  Expression simplify() {
    return new Atan(arg.simplify());
  }

  @override
  dynamic evaluate(EvaluationType type, ContextModel context) {
    final dynamic argEval = arg.evaluate(type, context);

    if (type == EvaluationType.REAL) {
      return math.atan(argEval);
    }

    // TODO VECTOR and INTERVAL evaluation
    throw new UnimplementedError('Can not evaluate $name on $type yet.');
  }
}

/**
 * The absolute value function.
 */
class Abs extends DefaultFunction {
  /**
   * Creates a new absolute value function with given argument expression.
   */
  Abs(Expression arg) : super._unary('abs', arg);

  /// The argument of this absolute value function.
  Expression get arg => getParam(0);

  /// The differentiation of Abs is Sgn
  //TODO No differentiation possible for x = 0
  @override
  Expression derive(String toVar) => new Sgn(arg) * arg.derive(toVar);

  /**
   * Possible simplifications:
   */
  @override
  Expression simplify() => new Abs(arg.simplify());

  @override
  dynamic evaluate(EvaluationType type, ContextModel context) {
    final dynamic argEval = arg.evaluate(type, context);

    if (type == EvaluationType.REAL) {
      return argEval.abs();
    }

    if (type == EvaluationType.VECTOR) {
      //TODO apply function to all vector elements
    }

    throw new UnimplementedError('Can not evaluate $name on $type yet.');
  }
}

/**
 * The ceil function.
 */
class Ceil extends DefaultFunction {
  /**
   * Creates a new ceil function with given argument expression.
   */
  Ceil(Expression arg) : super._unary('ceil', arg);

  /// The argument of this ceil function.
  Expression get arg => getParam(0);

  /// Ceil never has a slope.
  //TODO No differentiation possible for integer x
  @override
  Expression derive(String toVar) => new Number(0);

  /**
   * Possible simplifications:
   *
   * 1. ceil(floor(a)) = floor(a)
   * 2. ceil(ceil(a)) = ceil(a)
   */
  @override
  Expression simplify() {
    final Expression sarg = arg.simplify();
    return sarg is Floor || sarg is Ceil ? sarg : new Ceil(sarg);
  }

  @override
  dynamic evaluate(EvaluationType type, ContextModel context) {
    final dynamic argEval = arg.evaluate(type, context);

    if (type == EvaluationType.REAL) {
      return argEval.ceil();
    }

    if (type == EvaluationType.VECTOR) {
      //TODO apply function to all vector elements
    }

    throw new UnimplementedError('Can not evaluate $name on $type yet.');
  }
}

/**
 * The floor function.
 */
class Floor extends DefaultFunction {
  /**
   * Creates a new floor function with given argument expression.
   */
  Floor(Expression arg) : super._unary('floor', arg);

  /// The argument of this floor function.
  Expression get arg => getParam(0);

  /// Floor never has a slope.
  //TODO No differentiation possible for integer x
  @override
  Expression derive(String toVar) => new Number(0);

  /**
   * Possible simplifications:
   *
   * 1. floor(floor(a)) = floor(a)
   * 2. floor(ceil(a)) = ceil(a)
   */
  @override
  Expression simplify() {
    final Expression sarg = arg.simplify();
    return (sarg is Floor) || (sarg is Ceil) ? sarg : new Floor(sarg);
  }

  @override
  dynamic evaluate(EvaluationType type, ContextModel context) {
    final dynamic argEval = arg.evaluate(type, context);

    if (type == EvaluationType.REAL) {
      return argEval.floor();
    }

    if (type == EvaluationType.VECTOR) {
      //TODO apply function to all vector elements
    }

    throw new UnimplementedError('Can not evaluate $name on $type yet.');
  }
}

/**
 * The sign function.
 */
class Sgn extends DefaultFunction {
  /**
   * Creates a new sign function with given argument expression.
   */
  Sgn(Expression arg) : super._unary('sgn', arg);

  /// The argument of this sign function.
  Expression get arg => getParam(0);

  //TODO not differentiable at 0.
  @override
  Expression derive(String toVar) => new Number(0);

  @override
  Expression simplify() => new Sgn(arg.simplify());

  @override
  dynamic evaluate(EvaluationType type, ContextModel context) {
    final dynamic argEval = arg.evaluate(type, context);

    if (type == EvaluationType.REAL) {
      if (argEval < 0) return -1.0;
      if (argEval == 0) return 0.0;
      if (argEval > 0) return 1.0;
    }

    throw new UnimplementedError('Can not evaluate $name on $type yet.');
  }
}
