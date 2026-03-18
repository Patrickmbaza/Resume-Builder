import { useResume } from '../../../hooks/useResume';
import { Input, Textarea, Button } from '../../ui/Inputs';
import { FiPlus, FiTrash2, FiMenu } from 'react-icons/fi';
import { DragDropContext, Droppable, Draggable } from '@hello-pangea/dnd';
import type { DropResult } from '@hello-pangea/dnd';

export default function Step6Projects() {
  const { data, addProject, updateProject, removeProject, reorderProjects } = useResume();

  const handleDragEnd = (result: DropResult) => {
    if (!result.destination) return;
    const items = Array.from(data.projects);
    const [moved] = items.splice(result.source.index, 1);
    items.splice(result.destination.index, 0, moved);
    reorderProjects(items);
  };

  return (
    <div className="flex flex-col gap-5">
      <div className="flex justify-between items-center">
        <p className="text-slate-500 text-sm">Highlight your best projects. Drag to reorder.</p>
        <Button onClick={addProject} variant="secondary" size="sm"><FiPlus /> Add Project</Button>
      </div>

      <DragDropContext onDragEnd={handleDragEnd}>
        <Droppable droppableId="projects">
          {(provided) => (
            <div {...provided.droppableProps} ref={provided.innerRef} className="flex flex-col gap-4">
              {data.projects.map((proj, index) => (
                <Draggable key={proj.id} draggableId={proj.id} index={index}>
                  {(provided) => (
                    <div
                      ref={provided.innerRef}
                      {...provided.draggableProps}
                      className="bg-white border border-slate-100 rounded-xl p-5 relative shadow-sm"
                    >
                      <div
                        {...provided.dragHandleProps}
                        className="absolute left-0 top-0 bottom-0 w-7 flex items-center justify-center cursor-grab text-slate-300 hover:text-slate-500"
                      >
                        <FiMenu size={14} />
                      </div>
                      <div className="ml-5">
                        <div className="flex justify-between items-center mb-4">
                          <span className="text-xs font-bold text-slate-400 uppercase tracking-wider">Project {index + 1}</span>
                          <button
                            onClick={() => removeProject(proj.id)}
                            className="text-red-400 hover:text-red-600 p-1.5 bg-red-50 rounded-lg transition"
                          >
                            <FiTrash2 size={14} />
                          </button>
                        </div>
                        <div className="grid grid-cols-1 md:grid-cols-2 gap-3 mb-3">
                          <Input label="Project Name" placeholder="E-commerce Dashboard" value={proj.name} onChange={e => updateProject(proj.id, { name: e.target.value })} />
                          <Input label="Your Role" placeholder="Lead Developer" value={proj.role} onChange={e => updateProject(proj.id, { role: e.target.value })} />
                          <div className="md:col-span-2">
                            <Input label="Technologies Used" placeholder="React, Node.js, MongoDB" value={proj.technologies} onChange={e => updateProject(proj.id, { technologies: e.target.value })} />
                          </div>
                          <div className="md:col-span-2">
                            <Input label="Project URL / Repository" placeholder="github.com/username/project" value={proj.link} onChange={e => updateProject(proj.id, { link: e.target.value })} />
                          </div>
                        </div>
                        <Textarea
                          label="Description"
                          placeholder="Built a full-stack dashboard that allows users to track orders in real time..."
                          value={proj.description}
                          onChange={e => updateProject(proj.id, { description: e.target.value })}
                          className="min-h-[110px]"
                        />
                      </div>
                    </div>
                  )}
                </Draggable>
              ))}
              {provided.placeholder}
            </div>
          )}
        </Droppable>
      </DragDropContext>

      {data.projects.length === 0 && (
        <div className="text-center p-10 border-2 border-dashed border-slate-100 rounded-xl">
          <p className="text-slate-400 text-sm mb-4">No projects added yet.</p>
          <Button onClick={addProject} variant="outline"><FiPlus /> Add First Project</Button>
        </div>
      )}
    </div>
  );
}
