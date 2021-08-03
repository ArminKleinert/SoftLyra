module buildins;

import types;
import lyrafunction;
import evaluate;

import std.stdio;

void initializeGlobalEnv(Env env) {
    void addFn(string name, int minargs, bool variadic, bool ispure, bool isMacro,
            LyraObj delegate(Cons, Env) fnBody) {
        auto maxargs = variadic ? int.max : minargs;
        env.set(symbol(name), new NativeLyraFunc(name, minargs, maxargs,
                variadic, ispure, isMacro, fnBody));
    }

    auto numbercode(string op) {
        return "auto arg0 = xs.car;
        auto arg1 = xs.cdr.car;
        if (arg0.type == fixnum_id) {
            if (arg1.type == fixnum_id) {
                return LyraObj.makeFixnum(arg0.fixnum_val " ~ op ~ " arg1.fixnum_val);
            } else if (arg1.type == real_id) {
                return LyraObj.makeReal(arg0.fixnum_val "
            ~ op ~ " arg1.real_val);
            } else {
                return nil();
            }
        } else if (arg0.type == real_id) {
            if (arg1.type == fixnum_id) {
                return LyraObj.makeReal(arg0.real_val " ~ op
            ~ " arg1.fixnum_val);
            } else if (arg1.type == real_id) {
                return LyraObj.makeReal(arg0.real_val " ~ op ~ " arg1.real_val);
            } else {
                return nil();
            }
        } else {
            return nil();
        }";
    }

    auto comparator(string op) {
        return "auto arg0 = xs.car;
        auto arg1 = xs.cdr.car;
        if (arg0.type == fixnum_id) {
            if (arg1.type == fixnum_id) {
                return LyraObj.makeBoolean(arg0.fixnum_val " ~ op ~ " arg1.fixnum_val);
            } else if (arg1.type == real_id) {
                return LyraObj.makeBoolean(arg0.fixnum_val "
            ~ op ~ " arg1.real_val);
            } else {
                return LyraObj.makeBoolean(false);
            }
        } else if (arg0.type == real_id) {
            if (arg1.type == fixnum_id) {
                return LyraObj.makeBoolean(arg0.real_val " ~ op ~ " arg1.fixnum_val);
            } else if (arg1.type == real_id) {
                return LyraObj.makeBoolean(arg0.real_val " ~ op ~ " arg1.real_val);
            } else {
                return LyraObj.makeBoolean(false);
            }
        } else if (arg0.type == string_id && arg1.type == string_id) {
            return LyraObj.makeBoolean(arg0.string_val "
            ~ op ~ " arg1.string_val);
        } else if (arg0.type == symbol_id && arg1.type == symbol_id) {
            return LyraObj.makeBoolean(arg0.symbol_val "
            ~ op ~ " arg1.symbol_val);
        } else if (arg0.type == char_id && arg1.type == char_id) {
            return LyraObj.makeBoolean(arg0.char_val " ~ op
            ~ " arg1.char_val);
        } else {
            return LyraObj.makeBoolean(arg0 " ~ op ~ " arg1);
        }";
    }

    addFn("+", 2, false, true, false, (xs, env) { mixin(numbercode("+")); });
    addFn("-", 2, false, true, false, (xs, env) { mixin(numbercode("-")); });
    addFn("*", 2, false, true, false, (xs, env) { mixin(numbercode("*")); });
    addFn("/", 2, false, true, false, (xs, env) { mixin(numbercode("/")); });
    addFn("%", 2, false, true, false, (xs, env) { mixin(numbercode("%")); });
    addFn("=", 2, false, true, false, (xs, env) { mixin(comparator("==")); });
    addFn("<", 2, false, true, false, (xs, env) { mixin(comparator("<")); });
    addFn(">", 2, false, true, false, (xs, env) { mixin(comparator(">")); });
    addFn("<=", 2, false, true, false, (xs, env) { mixin(comparator("<=")); });
    addFn(">=", 2, false, true, false, (xs, env) { mixin(comparator(">=")); });

    addFn("&&", 2, true, true, true, (xs, env) {
        while (!xs.isNil()) {
            if (eval(xs.car, env).isFalsy()) {
                return LyraObj.makeBoolean(false);
            }
            xs = xs.next();
        }
        return LyraObj.makeBoolean(true);
    });

    addFn("||", 2, true, true, true, (xs, env) {
        while (!xs.isNil()) {
            if (!eval(xs.car, env).isFalsy()) {
                return LyraObj.makeBoolean(true);
            }
            xs = xs.next();
        }
        return LyraObj.makeBoolean(false);
    });

    addFn("cons", 2, false, true, false, (xs, env) {
        if (!isConsOrNil(xs.cdr.car)) {
            throw new LyraError("cons: cdr must be another cons or nil.", callStack);
        }
        return cons(xs.car, cast(Cons) xs.cdr.car);
    });
    addFn("_car", 1, false, true, false, (xs, env) {
        if (xs.car.type != cons_id) {
            throw new LyraError("_car: Expected Cons.", callStack());
        }
        return xs.car.car;
    });
    addFn("_cdr", 1, false, true, false, (xs, env) {
        if (xs.car.type != cons_id) {
            throw new LyraError("_cdr: Expected Cons.", callStack());
        }
        return xs.car.cdr;
    });

    addFn("vector", 0, true, true, false, (xs, env) {
        return vector(listToVector(xs));
    });

    addFn("_vector-append", 2, false, true, false, (xs, env) {
        if (xs.car.type != vector_id) {
            throw new LyraError("_vector-append: Expected vector.", callStack());
        }
        return vector(xs.car.vector_val ~ xs.cdr.car);
    });

    addFn("_vector-get", 2, false, true, false, (xs, env) {
        if (xs.car.type != vector_id || xs.cdr.car.type != fixnum_id) {
            throw new LyraError("_vector-get: Expected vector and fixnum.", callStack());
        }
        return xs.car.vector_val[xs.cdr.car.fixnum_val];
    });

    addFn("_vector-size", 1, false, true, false, (xs, env) {
        if (xs.car.type != vector_id) {
            throw new LyraError("_vector-size: Expected vector.", callStack());
        }
        return LyraObj.makeFixnum(xs.car.vector_val.length);
    });

    addFn("_vector-iterate", 3, false, true, false, (xs, env) {
        if (xs.car.type != vector_id || xs.cdr.cdr.car.type != func_id) {
            throw new LyraError("_vector-iterate: Expected vector, then any, then function.",
                callStack());
        }
        auto vec = xs.car.vector_val;
        auto accumulator = xs.cdr.car;
        auto fn = xs.cdr.cdr.car.func_val;
        for (fixnum i = 0; i < vec.length; i++) {
            accumulator = fn.call(list(accumulator, vec[i], LyraObj.makeFixnum(i)), env);
        }
        return accumulator;
    });

    addFn("_string", 0, true, true, false, (xs, env) {
        auto s = "";
        while (!xs.isNil()) {
            if (xs.car.type == string_id)
                s ~= xs.car.string_val;
            else
                s ~= xs.car.toString();
            xs = xs.next();
        }
        return LyraObj.makeString(s);
    });

    addFn("_println!", 1, false, false, false, (xs, env) {
        if (xs.car.type == string_id)
            writeln(xs.car.string_val);
        else
            writeln(xs.car.toString());
        return Cons.nil();
    });

    addFn("box", 1, false, false, false, (xs, env) { return box(xs.car); });
    addFn("unbox", 1, false, false, false, (xs, env) { return unbox(xs.car); });
    addFn("box-set!", 2, false, false, false, (xs, env) {
        boxSet(xs.car, xs.cdr.car);
        return xs.cdr.car;
    });

    addFn("defined?", 1, false, false, false, (xs, env) {
        if (xs.car.type != symbol_id)
            return LyraObj.makeBoolean(false);
        auto res = env.safeFind(xs.car.symbol_val);
        return LyraObj.makeBoolean(res !is null);
    });

    addFn("measure", 2, false, false, false, (xs, env) {
        auto median(long[] arr) {
            import std.algorithm.sorting;

            sort(arr);
            auto len = arr.length;
            return (arr[(len - 1) / 2] + arr[len / 2]) / 2;
        }

        import std.datetime.stopwatch;
        import core.time : Duration;

        auto times = xs.car.fixnum_val;
        auto fn = xs.cdr.car.func_val;
        auto args = Cons.nil();

        long[] drs = [];
        auto sw = StopWatch(AutoStart.no);

        for (; times > 0; times--) {
            sw.reset();
            sw.start();
            fn.call(args, env);
            sw.stop();
            drs ~= sw.peek().total!"nsecs";
        }

        return LyraObj.makeReal(median(drs) / 1000000000.0);
    });

    addFn("eval!", 1, false, false, false, (xs, env) {
        return evalKeepLast(xs.car, env);
    });
    addFn("parse", 1, false, false, false, (xs, env) {
        import reader;

        if (xs.car.type != string_id) {
            throw new LyraError("parse: Expected string.", callStack());
        }
        return make_ast(tokenize(xs.car.value.string_val));
    });
    addFn("slurp!", 1, false, false, false, (xs, env) {
        import std.file : readText;

        if (xs.car.type != string_id) {
            throw new LyraError("slurp!: Expected string.", callStack());
        }
        return LyraObj.makeString(readText(xs.car.value.string_val));
    });

    addFn("lyra-type-id", 1, false, true, false, (xs, env) {
        return xs.car.objtype();
    });

    addFn("define-record", 2, true, false, true, (xs, env) {
        auto type_id = eval(xs.car, env);
        auto typename = xs.cdr.car;

        if (type_id.type != fixnum_id) {
            throw new LyraError("define-record: First argument must be a type-id.", callStack());
        }
        if (typename.type != symbol_id) {
            throw new LyraError("define-record: Second argument must be a symbol.", callStack());
        }

        xs = xs.cdr.cdr;

        Symbol[] members = [];
        while (!xs.isNil()) {
            if (xs.car.type != symbol_id) {
                throw new LyraError("define-record: Name of member must be a symbol.", callStack());
            }
            members ~= xs.car.symbol_val;
            xs = xs.cdr;
        }

        auto type = type_id.fixnum_val;
        if (type < 0 || type > uint.max) {
            throw new LyraError("define-record: type id not in range 0 .. 2**32-1", callStack());
        }

        LyraRecord.create(cast(uint) type, typename.symbol_val, Env.globalEnv(), members);

        //writeln(Env.globalEnv().toStringWithoutParents());

        return Cons.nil();
    });

    addFn("symbol", 1, false, true, false, (xs, env) {
        if (xs.car.type == string_id) {
            return LyraObj.makeSymbol(xs.car.string_val);
        }
        return LyraObj.makeSymbol(xs.car.toString());
    });

    /*
    addFn("char->fixnum", 1, false, true, false, (xs, env) {
        if (xs.car.type != char_id)
            throw new LyraError("char->fixnum: Expected char.",callStack());
        return LyraObj.makeFixnum(cast(fixnum) xs.car.char_val);
    });

    addFn("fixnum->char", 1, false, true, false, (xs, env) {
        if (xs.car.type != fixnum_id)
            throw new LyraError("fixnum->char: Expected fixnum.",callStack());
        return LyraObj.makeFixnum(cast(char) xs.car.fixnum_val);
    });
    */
}