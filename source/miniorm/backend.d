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
 * Module to hold base code for backends
 * 
 * License:   $(HTTP https://www.gnu.org/licenses/agpl-3.0.html, AGPL 3.0).
 * Copyright: Copyright (C) 2023 Mai-Lapyst
 * Authors:   $(HTTP codeark.it/Mai-Lapyst, Mai-Lapyst)
 */

module miniorm.backend;

interface Schema {
    Backend getBackend();

    Database[] list();
    Database get(string name);
    Database create(string name);
    bool remove(string name);
}

interface Database {
    Backend getBackend();
    Schema getSchema();

    Collection[] list();
    Collection get();
    Collection create(string name);
    bool remove(string name);
}

interface Collection {
    Backend getBackend();
    Schema getSchema();
    Database getDatabase();
}

interface Backend {
    void connect(string dsn);

    Schema[] list();
    Schema get(string name);
    Schema create(string name);
    bool remove(string name);
    Schema defaultSchema();
}
