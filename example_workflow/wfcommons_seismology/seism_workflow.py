import pathlib
from wfcommons.wfchef.recipes import SeismologyRecipe
from wfcommons import WorkflowGenerator


num_tasks = [1, 2, 4, 16, 32, 64, 128, 256, 512]

recipe = SeismologyRecipe.from_num_tasks(num_tasks=100, runtime_factor=1.1, input_file_size_factor=1.5, output_file_size_factor=0.8)

generator = WorkflowGenerator(recipe)
workflow = generator.build_workflow()

# workflow.write_json(pathlib.Path('test-seis.json'))

workflow.write_dot(pathlib.Path('test-seis.dot'))