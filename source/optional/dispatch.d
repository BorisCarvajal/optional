module optional.dispatch;

import optional.optional: Optional;
import optional.internal;

enum isNullDispatchable(T) = is(T == class) || is(T == interface) || from!"std.traits".isPointer!T;

private string autoReturn(string expression)() {
    return `
        auto ref expr() {
            return ` ~ expression ~ `;
        }
        ` ~ q{
        auto ref val() {
            return expr();
        }
        alias R = typeof(val());
        static if (is(R == void)) {
            if (value.unwrap !is null) {
                val();
            }
        } else {
            if (value.unwrap is null) {
                return SafeNullDispatcher!R(no!R());
            }
            return SafeNullDispatcher!R(some(val()));
        }
    };
}

struct SafeNullDispatcher(T) {
    import std.traits: hasMember;

    Optional!T value;
    alias value this;

    this(Optional!T value) {
        this.value = value;
    }

    this(T value) {
        this.value = value;
    }

    template opDispatch(string name) if (hasMember!(T, name)) {
        import optional: no, some, unwrap;
        static if (is(typeof(__traits(getMember, T, name)) == function)) {
            auto ref opDispatch(Args...)(auto ref Args args) {
                mixin(autoReturn!("value.unwrap." ~ name ~ "(args)"));
            }
        } else static if (is(typeof(mixin("value.unwrap." ~ name)))) {
            // non-function field
            auto ref opDispatch(Args...)(auto ref Args args) {
                static if (Args.length == 0) {
                    mixin(autoReturn!("value.unwrap." ~ name));
                } else static if (Args.length == 1) {
                    mixin(autoReturn!("value.unwrap." ~ name ~ " = args[0]"));
                } else {
                    static assert(
                        0,
                        "Dispatched " ~ T.stringof ~ "." ~ name ~ " was resolved to non-function field that has more than one argument",
                    );
                }
            }
        } else {
            // member template
            template opDispatch(Ts...) {
                enum targs = Ts.length ? "!Ts" : "";
                auto ref opDispatch(Args...)(auto ref Args args) {
                    mixin(autoReturn!("value.unwrap." ~ name ~ targs ~ "(args)"));
                }
            }
        }
    }
}

auto dispatch(T)(auto ref T value) if (isNullDispatchable!T) {
    return SafeNullDispatcher!T(value);
}

auto dispatch(T)(auto ref Optional!T value) {
    import optional: unwrap;
    return SafeNullDispatcher!T(value.unwrap);
}


