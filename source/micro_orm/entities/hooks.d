/*
 * Copyright (C) 2023 Mai-Lapyst
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 * 
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/** 
 * Module for hooking queries (insert / update) on a entity
 * 
 * License:   $(HTTP https://www.gnu.org/licenses/agpl-3.0.html, AGPL 3.0).
 * Copyright: Copyright (C) 2023 Mai-Lapyst
 * Authors:   $(HTTP codeark.it/Mai-Lapyst, Mai-Lapyst)
 */
module micro_orm.entities.hooks;

template EntityHook(alias T, string hookName, alias queryTy)
{
    private enum hasHooks = __traits(hasMember, T, "__microOrm_" ~ hookName);
    static if (hasHooks) {
        alias hookMembers = __traits(getOverloads, T, "__microOrm_" ~ hookName);
        private struct HookState {
            template Impl(size_t i = 0) {
                import std.traits;
                import std.meta : AliasSeq;
                static if (i == hookMembers.length) {
                    enum Impl = "";
                } else {
                    alias m = hookMembers[i];
                    alias ret = ReturnType!m;
                    alias params = Parameters!m;
                    static assert(
                        is(ReturnType!m == void),
                        "MicroOrm: member `" ~ fullyQualifiedName!m ~ "` needs have a returntype of `void`"
                    );
                    static if (is(params == AliasSeq!())) {
                        // call before values are captured
                        pragma(msg, "Entity `" ~ fullyQualifiedName!T ~ "`: Found before hook for " ~ hookName);
                        enum Impl = "enum hasOnBefore = true; " ~ Impl!(i+1);
                    }
                    else static if (is(params == AliasSeq!(queryTy))) {
                        // call after values are captured
                        pragma(msg, "Entity `" ~ fullyQualifiedName!T ~ "`: Found after hook for " ~ hookName);
                        enum Impl = "enum hasOnAfter = true; " ~ Impl!(i+1);
                    }
                    else static if (is(params == AliasSeq!(queryTy, Connection))) {
                        // call lazily before execution
                        pragma(msg, "Entity `" ~ fullyQualifiedName!T ~ "`: Found delayed hook for " ~ hookName);
                        enum Impl = "enum hasOnExec = true; " ~ Impl!(i+1);
                    }
                    else {
                        static assert(0,
                            "MicroOrm: member `" ~ fullyQualifiedName!m ~ "` needs to have a signature of either"
                                ~ " `void()`, `void(" ~ queryTy.stringof ~ ")` or `void(" ~ queryTy.stringof ~ ", Connection)`"
                                ~ " but has `" ~ typeof(m).stringof ~ "`"
                        );
                    }
                }
            }
            mixin( Impl!() );
        }
    }
    template onBefore() {
        static if (hasHooks && __traits(hasMember, HookState, "hasOnBefore")) {
            enum onBefore = "this.__microOrm_" ~ hookName ~ "();";
        } else {
            enum onBefore = "";
        }
    }
    template onAfter() {
        static if (hasHooks && __traits(hasMember, HookState, "hasOnAfter")) {
            enum onAfter = "this.__microOrm_" ~ hookName ~ "(q);";
        } else {
            enum onAfter = "";
        }
    }
    template onExec() {
        static if (hasHooks && __traits(hasMember, HookState, "hasOnExec")) {
            enum onExec = "q.addHook(&this.__microOrm_" ~ hookName ~ ");";
        } else {
            enum onExec = "";
        }
    }
}

enum bool hasHookMember(alias T, string hookName) = __traits(hasMember, T, "__microOrm_" ~ hookName);
