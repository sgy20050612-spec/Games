extends RefCounted
## Same rounded, noise-warped coastline used by the water/terrain shader.
static var depth_cache = {}

static func noise_at(p):
	return sin(p.x*.009+p.y*.003)*11+sin(p.y*.019-p.x*.007)*6+sin(p.x*.037+p.y*.029)*2

static func distance_at(p, land_size):
	var q=(p-Vector2(land_size/2.0,land_size/2.0)).abs()-Vector2(land_size/2.0-36,land_size/2.0-36)
	return Vector2(max(q.x,0),max(q.y,0)).length()+min(max(q.x,q.y),0)-96-noise_at(p)

static func depth(along,side,land_size):
	var key=Vector3i(int(round(along/2)),side,int(land_size))
	if depth_cache.has(key):return depth_cache[key]
	var low=0.0
	var high=110.0
	for i in range(9):
		var mid=(low+high)/2
		var p=Vector2(-mid,along) if side==0 else Vector2(land_size+mid,along) if side==1 else Vector2(along,-mid) if side==2 else Vector2(along,land_size+mid)
		if distance_at(p,land_size)<=0:low=mid
		else:high=mid
	var result=round((low+high)/4)*2
	depth_cache[key]=result
	return result
