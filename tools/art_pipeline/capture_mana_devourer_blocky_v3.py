"""Capture all previews from the imported Godot model, at deterministic times."""
import json,shutil,subprocess,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
STEM='mana_devourer_blocky_v3'
ASSET=Path('assets/generated/mana_devourers')/STEM
GODOT=Path(r'C:/Users/felipe campos/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe')
source=(ROOT/'tools/art_pipeline/verify_mana_devourer_blocky_v3.gd').read_text(encoding='utf-8')
head=source[:source.index('\tvar arrays :=')]
studio=source[source.index('\tplayer.play("ManaDevourer_Idle")'):source.index('\tfor i in 12:')]
capture='''
\troot.size = Vector2i(480, 480)
\tvar destination := OS.get_cmdline_user_args()[0]
\tvar manifest := {}
\tfor clip in ["Idle", "Walk", "Attack"]:
\t\tvar fps := 12 if clip == "Attack" else 6
\t\tvar count := 19 if clip == "Attack" else 96 if clip == "Idle" else 48
\t\tvar folder := destination.path_join(clip)
\t\tassert(DirAccess.make_dir_recursive_absolute(folder) == OK)
\t\tfor frame in count:
\t\t\tplayer.play("ManaDevourer_" + clip)
\t\t\tplayer.seek(float(frame) / fps, true)
\t\t\tplayer.advance(0)
\t\t\tplayer.pause()
\t\t\tskeleton.force_update_all_bone_transforms()
\t\t\tawait process_frame
\t\t\tawait RenderingServer.frame_post_draw
\t\t\tassert(root.get_texture().get_image().save_png(folder.path_join("%04d.png" % (frame+1))) == OK)
\t\tmanifest[clip] = {"frames": count, "fps": fps}
\tprint("MANA_NATIVE_PREVIEWS " + JSON.stringify(manifest))
\tquit(0)
'''
with tempfile.TemporaryDirectory(prefix='mana_v3_native_previews_') as temp:
    project=Path(temp); folder=project/ASSET; folder.mkdir(parents=True)
    (project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Mana Native Previews"\n[display]\nwindow/size/viewport_width=480\nwindow/size/viewport_height=480\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
    for p in (ROOT/ASSET).iterdir():
        if p.is_file() and (p.suffix in ('.glb','.png','.gd','.uid','.import')):
            shutil.copy2(p,folder/p.name)
    cache=project/'.godot/imported'; cache.mkdir(parents=True)
    for p in (ROOT/'.godot/imported').glob(STEM+'*'): shutil.copy2(p,cache/p.name)
    shutil.copy2(ROOT/'.godot/uid_cache.bin',project/'.godot/uid_cache.bin')
    (project/'capture.gd').write_text(head+studio+capture,encoding='utf-8')
    startup=subprocess.STARTUPINFO(); startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW; startup.wShowWindow=0
    output=ROOT/'art_source/mana_devourer_blocky_v3_review/native_frames'
    done=subprocess.run([str(GODOT),'--path',str(project),'--script','res://capture.gd','--',str(output)],
        capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=180,startupinfo=startup)
    log=done.stdout+done.stderr
    assert done.returncode==0 and 'SCRIPT ERROR' not in log and 'ERROR:' not in done.stderr,log
    print(log)
