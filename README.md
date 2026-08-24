# Mine Turtle Mapping API

---

## Introduction

Online Web API interface for Mine Turtles from CC: Tweaked to Interface with to share known blocks and request path finding directions.

This has got some improvements to makes.
Most notably I would like if the web api shows the blocks seen by the turtle API stored inside of the database
and uses some clever rendering trick to make sure the website doesnt brick

---

## Setup

To setup you will have to create a .env file and then initialise that env file like so
to your postgres installation and password (At least for local hosting);

```
DATABASE_URL="postgres://username:password@localhost:5432/my_database"
```

After this, you should be all good to compile this code. The default Local Host used for this is
8080. So keep this in mind
