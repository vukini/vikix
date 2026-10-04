# Tables

A table of the kind a 7-inch e-ink screen collapses:

| Command | What it does | Since |
|---|---|---|
| `.tables` | lists the tables | 3.0 |
| `.schema` | shows the CREATE statements | 3.0 |
| `.mode box` | draws boxes around results | 3.33 |

And a second, smaller one:

| Word | Meaning |
|---|---|
| libro | book |
| legi | to read |

A listing, whose indentation must survive every reader:

```python
def pages(db):
    for row in db.execute("PRAGMA page_count"):
        if row:
            return row[0]
```
