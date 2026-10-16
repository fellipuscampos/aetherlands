"""Small supported adornment correction on the current new scene, then save it."""
import argparse
from run_magic_school_batch import call, PIPELINE
if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--prefix',required=True)
    parser.add_argument('--axis',choices=('x','y','z'),required=True)
    parser.add_argument('--delta',type=float,required=True)
    args=parser.parse_args()
    assert abs(args.delta)<=.06
    code=f"""import bpy
st=bpy.app.driver_namespace['guardian_hall']
assert st['scene'].get('grand_military')
objects=[o for o in st['parts'] if o['part'].startswith({args.prefix!r})]
assert objects
for obj in objects:
    for vertex in obj.data.vertices:
        vertex.co[{('x','y','z').index(args.axis)}]+={args.delta!r}
exec(open({str(PIPELINE/'resume_grand_military_draft.py')!r},encoding='utf-8').read())
"""
    print(call(code))
