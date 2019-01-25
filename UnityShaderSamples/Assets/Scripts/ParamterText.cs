using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

[RequireComponent(typeof(Text))]
public class ParamterText : MonoBehaviour {

    public Renderer targetRenderer;

    public string PropertyName;
    private Text text;

	// Use this for initialization
	void Start () {
        text = GetComponent<Text>();
	}
	
	// Update is called once per frame
	void Update () {
		if(!text || !targetRenderer) { return; }

        text.text = PropertyName + ":" + targetRenderer.material.GetFloat(PropertyName);
	}
}
