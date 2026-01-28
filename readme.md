# MicroOrm

A minimal jet complete orm for dlang projects

Notice: micro_orm will NOT recieve further updates; please switch to [ninox.d-oxm](https://codearq.net/bithero-dlang/ninox.d-oxm).

## License

The code in this repository is licensed under AGPL-3.0-or-later; for more details see the `LICENSE` file in the repository.

## Example

```d
module app;

import micro_orm;
import micro_orm.entities.generators.sequence;

// Explicitly import the backend's module in order for it to be available
import micro_orm.backend_libmariadb;

// @Entity is needed to discover this entity
@Entity
// @Storage is an optional UDA to specify the storage name of the entity
// this name gets used to create the table / collection inside the database
@Storage("person")
class Person {
    // With @Id fields get annotated as primary key(s); composite keys can be created
    // by annotating multiple fields with it
    @Id
    // @GeneratedValue tells MicroOrm that the value of this field is to be generated
    // on insertion. It looks for an __<fieldname>_gen static method or field (must be const!)
    // of type ValueGenerator for the generator to use.
    @GeneratedValue
    int id;

    // The valuegenerator to use for the `id` field. In this case it's an sequence generator
    static const ValueGenerator __id_gen = new SequenceGenerator!int("seq_person");

    // Normaly, MicroOrm dosnt need a @Field annotation and tries to deduce the used type in the
    // database from the native type, and uses the field's name as name inside the database.
    // But sometimes you need to change things a bit or to specify some other parameters for the type
    // such as maximum length; for this one can use the @Field UDA.
    @Field(FieldType.String, "fullname", 255)
    string name;

    int age;

    // To exclude fields from being persisted, annotate them with @IgnoreField
    @IgnoreField
    int some_tmp_field;

    // Mixin needed in order to generate the code neccessary for MicroOrm.
    // It also needs the current entity as generic parameter.
    mixin BaseEntity!Person;
}

void main() {
    // First, you need to create an Connection; this can be done by calling Connection.create.
    // It also accepts an list of generic arguments representing modules of your app
    // where MicroOrm should search after entities (annotated by @Entity).
    auto con = Connection.create!app(
        "mysql:host=<hostname>;db_name=<dbname>", "<db user>", "<db password>"
    );

    // When want to use entities dynamically onto connections,
    // you also can use following method to create the table of the entity:
    Person.MicroOrmModel.ensurePresence(con);

    // With <Entity>.find(), you can start a query
    auto q = Person.find();

    // On this query, you can do various things, such as filtering for
    // specific values / conditions on fields / columns.
    q.filter!"name"("Max");

    // You also can specify offsets, limits and even ordering
    q.limit(12);
    q.offset(0);
    q.order(Order.Asc);

    // To execute the query you'll need to run the all() or one() method;
    // the first returns an array with all entities matched while the later
    // restricts the query to one element and returns an `Optional!T` where T is
    // the entity in question.
    auto list = q.all(con);
    foreach (p; list) {
        writeln("name: `", p.name, "` | ", "age: ", p.age, "`");
    }

    {
        // To insert a entity, construct the object like normal...
        auto p = new Person();
        p.name = "Max";
        p.age = 30;

        // ... then call insert() to get the insertion query ...
        auto q = p.insert();

        // ... and finally call exec() with your connection to execute it.
        // This also calls all value generators for fields with generated values.
        q.exec(con);
    }

    {
        // To update a exisiting entity, use the update() method instead to create
        // an update query.
        Person p = /* ... */;
        p.update().exec(con);
    }

    {
        // To delete a exisiting entity, use the del() method instead to create
        // an delete query.
        Person p = /* ... */;
        p.del().exec(con);
    }
}
```
