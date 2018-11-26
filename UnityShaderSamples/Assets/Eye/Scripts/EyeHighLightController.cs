using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class EyeHighLightController : MonoBehaviour {

    [SerializeField]
    private Material material;

	// Use this for initialization
	void Start () {
		
	}
	
	// Update is called once per frame
	void Update () {
        if (!material) { return; }


        material.SetVector("_Position", new Vector4(transform.position.x, transform.position.y, transform.position.z, 1.0f));
        //float angleDir = transform.eulerAngles.z * (Mathf.PI / 180.0f);
        //Vector3 dir = new Vector3(Mathf.Cos(angleDir), Mathf.Sin(angleDir), 0.0f);

        //float Xrad = transform.eulerAngles.x * (Mathf.PI / 180.0f);
        //float Yrad = transform.eulerAngles.x * (Mathf.PI / 180.0f);

        material.SetVector("_ObjectDirection", new Vector4(transform.forward.x, transform.forward.y, transform.forward.z, 0));
	}
}
