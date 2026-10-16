"""Evaluate shipped glTF hierarchy and skinning without Blender pose caches."""
import numpy as np
from human_texture_glb import read_glb

def accessor(doc,binary,index):
    info=doc['accessors'][index];view=doc['bufferViews'][info['bufferView']]
    dtype={5120:'i1',5121:'u1',5122:'<i2',5123:'<u2',5125:'<u4',5126:'<f4'}[info['componentType']]
    n={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[info['type']]
    return np.ndarray((info['count'],n),dtype=dtype,buffer=binary,
        offset=view.get('byteOffset',0)+info.get('byteOffset',0),
        strides=(view.get('byteStride',np.dtype(dtype).itemsize*n),np.dtype(dtype).itemsize)).copy()

def quaternion_matrix(q):
    x,y,z,w=q/np.linalg.norm(q)
    return np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],
        [2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],
        [2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])

class PoseModel:
    def __init__(self,path):
        self.doc,self.binary=read_glb(path.read_bytes());doc=self.doc
        self.parent={c:i for i,n in enumerate(doc['nodes']) for c in n.get('children',[])}
        self.by_name={n['name']:i for i,n in enumerate(doc['nodes']) if 'name' in n}
        self.joints=doc['skins'][0]['joints'];self.names=[doc['nodes'][i]['name'] for i in self.joints]
        self.inverse_bind=accessor(doc,self.binary,doc['skins'][0]['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1)
        self.clips={}
        for clip in doc['animations']:
            channels=[]
            for channel in clip['channels']:
                sampler=clip['samplers'][channel['sampler']]
                channels.append((channel['target']['node'],channel['target']['path'],
                    accessor(doc,self.binary,sampler['input']).ravel(),accessor(doc,self.binary,sampler['output'])))
            self.clips[clip['name']]=channels
        self.rest=self.worlds()

    def worlds(self,clip=None,time=0.):
        changes={}
        if clip:
            for i,p,times,values in self.clips[clip]:
                k=min(len(times)-1,max(0,int(np.searchsorted(times,time,side='right')-1)))
                if k==len(times)-1 or abs(time-times[k])<.000001:v=values[k]
                else:
                    t=(time-times[k])/(times[k+1]-times[k]);a,b=values[k:k+2]
                    if p=='rotation' and np.dot(a,b)<0:b=-b
                    v=a*(1-t)+b*t
                changes.setdefault(i,{})[p]=v
        result={}
        def world(i):
            if i in result:return result[i]
            node=self.doc['nodes'][i];values=changes.get(i,{})
            if 'matrix' in node and not values:m=np.array(node['matrix']).reshape(4,4).T
            else:
                m=np.eye(4);m[:3,3]=values.get('translation',node.get('translation',[0,0,0]))
                m[:3,:3]=quaternion_matrix(np.array(values.get('rotation',node.get('rotation',[0,0,0,1]))))*np.array(values.get('scale',node.get('scale',[1,1,1])))
            if i in self.parent:m=world(self.parent[i])@m
            result[i]=m;return m
        for i in range(len(self.doc['nodes'])):world(i)
        return result

    def skin_matrices(self,worlds):
        return np.array([worlds[i] for i in self.joints])@self.inverse_bind

    def geometry(self,uv_layer=0):
        points=[];ids=[];uv=[]
        for primitive in self.doc['meshes'][0]['primitives']:
            a=primitive['attributes'];weights=accessor(self.doc,self.binary,a['WEIGHTS_0'])
            assert ((weights>.00001).sum(axis=1)==1).all()
            points.append(accessor(self.doc,self.binary,a['POSITION']))
            joints=accessor(self.doc,self.binary,a['JOINTS_0'])
            ids.append(joints[np.arange(len(joints)),np.argmax(weights,axis=1)])
            uv.append(accessor(self.doc,self.binary,a['TEXCOORD_'+str(uv_layer)]))
        return np.concatenate(points),np.concatenate(ids),np.concatenate(uv)

    def skinned(self,worlds,points,ids):
        p=np.c_[points,np.ones(len(points))]
        return np.einsum('nij,nj->ni',self.skin_matrices(worlds)[ids],p)[:,:3]
