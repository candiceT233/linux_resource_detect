# Issue running write_dot and json
```
Traceback (most recent call last):
  File "/qfs/people/tang584/scripts/linux_resource_detect/example_workflow/wfcommons_seismology/seism_workflow.py", line 2, in <module>
    from wfcommons.wfchef.recipes import SeismologyRecipe
  File "/people/tang584/.local/lib/python3.10/site-packages/wfcommons/__init__.py", line 21, in <module>
    from .wfinstances import Instance, InstanceAnalyzer, InstanceElement
  File "/people/tang584/.local/lib/python3.10/site-packages/wfcommons/wfinstances/__init__.py", line 12, in <module>
    from .schema import SchemaValidator
  File "/people/tang584/.local/lib/python3.10/site-packages/wfcommons/wfinstances/schema.py", line 12, in <module>
    import jsonschema
  File "/people/tang584/.local/lib/python3.10/site-packages/jsonschema/__init__.py", line 16, in <module>
    from jsonschema.validators import (
  File "/people/tang584/.local/lib/python3.10/site-packages/jsonschema/validators.py", line 20, in <module>
    from jsonschema_specifications import REGISTRY as SPECIFICATIONS
  File "/people/tang584/.local/lib/python3.10/site-packages/jsonschema_specifications/__init__.py", line 10, in <module>
    REGISTRY = (_schemas() @ _EMPTY_REGISTRY).crawl()
  File "/people/tang584/.local/lib/python3.10/site-packages/referencing/_core.py", line 384, in __rmatmul__
    for resource in new:
  File "/people/tang584/.local/lib/python3.10/site-packages/jsonschema_specifications/_core.py", line 37, in _schemas
    contents = json.loads(path.read_text(encoding="utf-8"))
  File "/share/apps/python/miniconda23.3.1/lib/python3.10/json/__init__.py", line 346, in loads
    return _default_decoder.decode(s)
  File "/share/apps/python/miniconda23.3.1/lib/python3.10/json/decoder.py", line 340, in decode
    raise JSONDecodeError("Extra data", s, end)
json.decoder.JSONDecodeError: Extra data: line 1 column 3 (char 2)
```

# uninstalled and reinstalled error
```
python3 -m pip install wfcommons
Defaulting to user installation because normal site-packages is not writeable
Requirement already satisfied: wfcommons in /qfs/people/tang584/.local/lib/python3.10/site-packages (1.0)
ERROR: Could not install packages due to an OSError: [Errno 2] No such file or directory: '/qfs/people/tang584/.local/lib/python3.10/site-packages/wfcommons-1.0.dist-info/METADATA'
```