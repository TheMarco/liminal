"""Validate the actual exported GLBs: budgets, finite attributes and triangle area."""
from pathlib import Path
import json,struct,math
ROOT=Path(__file__).resolve().parents[1]
ASSETS={
 'mall_photo_booth/mall_photo_booth':(4000,2),
 'mall_rocket_ride/mall_rocket_ride':(4500,1),
 'vegas_ice_machine/vegas_ice_machine':(4000,2),
 'vegas_bellhop_cart/vegas_bellhop_cart':(4500,1),
 'vegas_cigarette_machine/vegas_cigarette_machine':(4000,2),
 'office_coffee_machine/office_coffee_machine':(4000,2),
 'school_overhead_projector/school_overhead_projector':(4000,1),

 'airport_walkway/standard/airport_walkway':(5000,3),
 'airport_walkway/long/airport_walkway_long':(5000,3),
 'airport_escalator/airport_escalator':(6000,2),
 'school_trophy_case/school_trophy_case':(6000,3),
 'school_furniture/bleachers/school_bleachers':(4500,1),
 'school_furniture/cafeteria_table/school_cafeteria_table':(4000,1),
 'school_furniture/cupboard/school_cupboard':(1500,1),
 'service_fixtures/school_servery/school_servery':(6000,2),
 'service_fixtures/prison_shower/prison_shower':(1200,1),
 'service_fixtures/prison_mess_table/prison_mess_table':(2500,1),
 'airport_gate_desk/airport_gate_desk':(5000,2),
 'airport_carousel/airport_carousel':(4500,3),
 'asylum_medical/ect_machine':(6000,2),
 'asylum_medical/restraint_table':(6500,1),
 'vt100/vt100_monitor':(2500,2),
 'vt100/vt100_keyboard':(4000,1),
 'mall_merchandise/mall_merchandise_station':(6000,3),
 'mall_merchandise/mall_merchandise_display':(3500,2),
 'bloom_incubator/bloom_incubator':(8000,6),
}
def read(path):
 data=path.read_bytes();assert data[:4]==b'glTF'
 n=struct.unpack_from('<I',data,12)[0];doc=json.loads(data[20:20+n]);binary=data[28+n:]
 def accessor(index):
  a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']]
  code={5126:'f',5125:'I',5123:'H',5121:'B'}[a['componentType']]
  components={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
  fmt='<'+code*components;size=struct.calcsize(fmt)
  start=v.get('byteOffset',0)+a.get('byteOffset',0);stride=v.get('byteStride',size)
  return [struct.unpack_from(fmt,binary,start+i*stride) for i in range(a['count'])]
 return doc,accessor

failures=[]
for name,(budget,surfaces) in ASSETS.items():
 try:
  path=ROOT/'models/authored'/f'{name}.glb';doc,get=read(path)
  count=0;draws=0;degenerate=0
  for mesh in doc['meshes']:
   for p in mesh['primitives']:
    draws+=1;assert p.get('mode',4)==4, 'non-triangle geometry'
    for key,idx in p['attributes'].items():
     assert all(math.isfinite(v) for row in get(idx) for v in row),(name,key,'nonfinite')
    verts=get(p['attributes']['POSITION']);indices=[v[0] for v in get(p['indices'])] if 'indices'in p else list(range(len(verts)))
    assert len(indices)%3==0
    count+=len(indices)//3
    for i in range(0,len(indices),3):
     a,b,c=[verts[j] for j in indices[i:i+3]];u=[b[j]-a[j] for j in range(3)];v=[c[j]-a[j] for j in range(3)]
     cross=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
     if sum(x*x for x in cross)<1e-22:degenerate+=1
  assert 0<count<=budget,(count,budget)
  assert draws<=surfaces,(draws,surfaces)
  assert degenerate==0,('degenerate triangles',degenerate)
  assert doc.get('images') and all('bufferView' in im for im in doc['images']),'textures must be embedded'
  print(f'PASS {name}: {count:,} triangles, {draws} surfaces, {path.stat().st_size//1024:,} KiB')
 except (AssertionError,KeyError,FileNotFoundError) as exc:failures.append((name,str(exc)))
for name,error in failures:print('FAIL',name,error)
raise SystemExit(bool(failures))
