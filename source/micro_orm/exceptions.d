module micro_orm.exceptions;

/**
 * Helper template to simply inherit the default execption constructors
 */
template ExceptionInheritConstructors() {
    @nogc @safe pure nothrow this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null) {
        super(msg, file, line, nextInChain);
    }

    @nogc @safe pure nothrow this(string msg, Throwable nextInChain, string file = __FILE__, size_t line = __LINE__) {
        super(msg, file, line, nextInChain);
    }
}

/**
 * Generic exception for MicroOrm. All exceptions inside the framework and
 *  all it's backends should extend this class.
 */
class MicroOrmException : Exception {
    mixin ExceptionInheritConstructors;
}

/**
 * Exception for connection problems. Mostly thrown on connection startup or shutdown.
 */
class MicroOrmConnectionException : MicroOrmException {
    mixin ExceptionInheritConstructors;
}

/**
 * Exception for field problems.
 */
class MicroOrmFieldException : MicroOrmException {
    mixin ExceptionInheritConstructors;
}
