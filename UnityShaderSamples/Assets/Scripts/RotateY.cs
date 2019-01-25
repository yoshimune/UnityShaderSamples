using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class RotateY : MonoBehaviour {

    public Transform target;
    public float speed;
	
	// Update is called once per frame
	void Update () {
        var pos = target ? target.position : transform.position;
        transform.RotateAround(pos, Vector3.up, speed);
	}
}
