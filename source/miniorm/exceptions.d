module miniorm.exceptions;

template ExceptionInheritConstructors() {
    @nogc @safe pure nothrow this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null) {
        super(msg, file, line, nextInChain);
    }

    @nogc @safe pure nothrow this(string msg, Throwable nextInChain, string file = __FILE__, size_t line = __LINE__) {
        super(msg, file, line, nextInChain);
    }
}

class MiniOrmException : Exception {
    mixin ExceptionInheritConstructors;
}

class MiniOrmConnectionException : MiniOrmException {
    mixin ExceptionInheritConstructors;
}

class MiniOrmFieldException : MiniOrmException {
    mixin ExceptionInheritConstructors;
}
