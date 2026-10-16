extends SceneTree

## Auditoria das texturas usadas por modelos/materiais 3D (otimização de 2026-10-14, docs/PERFORMANCE_GUIDE.md §6).
## Regra: toda textura de material 3D é importada como VRAM Compressed em alta qualidade (BC7 no desktop):
## 4× menos memória de vídeo que "Lossless" (RGBA8 descomprimido na GPU) e erro visualmente nulo (PSNR ~50 dB, menos
## de 0,05% dos pixels com diferença > 8/255 medido nos atlas do projeto). UI/ícones (assets/ui, assets/icons) e o
## terreno (Texture2DArray montado por TerrainTextureCatalog) ficam de fora — não são materiais de modelo.
##
## Uso (depois de exportar arte nova):
##   godot --headless --path . -s tools/perf/texture_import_audit.gd            # só lista o que está fora da regra
##   godot --headless --path . -s tools/perf/texture_import_audit.gd -- --fix   # corrige os .import
##   godot --headless --path . --import                                         # reimporta (BC7 leva alguns minutos)
## Sai com código 1 se sobrou textura fora da regra (sem --fix).

var found := {}
func _init() -> void:
	var fix := "--fix" in OS.get_cmdline_user_args()
	var files: Array = []
	_walk("res://assets", files)
	for path in files:
		var res = load(path)
		if res == null:
			continue
		if res is PackedScene:
			var inst = (res as PackedScene).instantiate()
			if inst != null:
				_scan_node(inst, path)
				inst.free()
		elif res is Material:
			_scan_material(res, path)
		elif res is Mesh:
			_scan_mesh(res, path)
	var wrong: Array[String] = []
	for tex_path in found:
		if not String(tex_path).begins_with("res://") or String(tex_path).begins_with("res://assets/ui") or String(tex_path).begins_with("res://assets/icons"):
			continue
		var import_path := String(tex_path) + ".import"
		if not FileAccess.file_exists(import_path):
			continue
		var text := FileAccess.get_file_as_string(import_path)
		if not text.contains("importer=\"texture\""):
			continue
		if text.contains("compress/mode=2") and text.contains("compress/high_quality=true"):
			continue
		wrong.append(String(tex_path))
		if fix:
			var regex := RegEx.create_from_string("compress/mode=[0-9]")
			text = regex.sub(text, "compress/mode=2")
			text = text.replace("compress/high_quality=false", "compress/high_quality=true")
			var f := FileAccess.open(import_path, FileAccess.WRITE)
			f.store_string(text)
			f.close()
	wrong.sort()
	for p in wrong:
		print(("FIXED " if fix else "NOT BC7 ") + p + "   (usada por " + String(found[p]) + ")")
	print("texturas 3D: %d, fora da regra: %d%s" % [found.size(), wrong.size(), " (corrigidas: rode --import)" if fix and not wrong.is_empty() else ""])
	quit(1 if (not fix and not wrong.is_empty()) else 0)

func _walk(dir: String, files: Array) -> void:
	var da := DirAccess.open(dir)
	if da == null:
		return
	if FileAccess.file_exists(dir + "/.gdignore"):
		return
	for d in da.get_directories():
		if d == "previews" or d.begins_with("."):
			continue
		_walk(dir + "/" + d, files)
	for f in da.get_files():
		if f.get_extension() in ["glb", "gltf", "tscn", "tres", "res"]:
			files.append(dir + "/" + f)

func _scan_node(node: Node, src: String) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		_scan_mesh(mi.mesh, src)
		for i in mi.get_surface_override_material_count():
			_scan_material(mi.get_surface_override_material(i), src)
	if node is GeometryInstance3D:
		_scan_material((node as GeometryInstance3D).material_override, src)
		_scan_material((node as GeometryInstance3D).material_overlay, src)
	if node is MultiMeshInstance3D and (node as MultiMeshInstance3D).multimesh != null:
		_scan_mesh((node as MultiMeshInstance3D).multimesh.mesh, src)
	if node is GPUParticles3D:
		var p := node as GPUParticles3D
		for i in p.draw_passes:
			_scan_mesh(p.get_draw_pass_mesh(i), src)
		_scan_material(p.process_material, src)
	for c in node.get_children():
		_scan_node(c, src)

func _scan_mesh(mesh: Mesh, src: String) -> void:
	if mesh == null:
		return
	for s in mesh.get_surface_count():
		_scan_material(mesh.surface_get_material(s), src)

func _scan_material(m, src: String) -> void:
	if m == null:
		return
	if m is BaseMaterial3D:
		for p in BaseMaterial3D.TEXTURE_MAX:
			var t = (m as BaseMaterial3D).get_texture(p)
			if t != null:
				_add(t, src)
	elif m is ShaderMaterial and (m as ShaderMaterial).shader != null:
		for u in (m as ShaderMaterial).shader.get_shader_uniform_list():
			var v = (m as ShaderMaterial).get_shader_parameter(u.name)
			if v is Texture:
				_add(v, src)
	if m is Material and (m as Material).next_pass != null:
		_scan_material((m as Material).next_pass, src)

func _add(t: Texture, src: String) -> void:
	var p := t.resource_path
	if p.is_empty() or "::" in p:
		p = "embedded:" + src
	if not found.has(p):
		found[p] = src
