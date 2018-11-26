using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class LookAt : MonoBehaviour {

    public Transform target;
	
	// Update is called once per frame
	void Update () {
        if (!target) { return; }
        transform.LookAt(target);
	}
}
