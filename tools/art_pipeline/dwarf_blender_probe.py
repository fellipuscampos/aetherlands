import bpy
result = {'version':bpy.app.version_string,'active_scene':bpy.context.scene.name,
          'file':bpy.data.filepath,'scenes':[s.name for s in bpy.data.scenes],
          'objects':len(bpy.data.objects),'mcp':'live'}
