// Copyright 2019 Esri.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import ArcGIS

extension AGSLabelDefinition{
    
    static func with(fieldName: String, textSymbol: AGSTextSymbol) throws -> AGSLabelDefinition {
        
        // https://developers.arcgis.com/web-map-specification/objects/labelingInfo/
        
        let labelDefinitionString = """
        {
        "allowOverrun": false,
        "deconflictionStrategy":"none",
        "labelExpressionInfo": { "expression": "$feature.\(fieldName);"},
        "labelPlacement": "esriServerPointLabelPlacementCenterCenter",
        "lineConnection": "none",
        "minScale": 0,
        "maxScale": 0,
        "multiPart": "labelLargest",
        "name":"\(fieldName)",
        "priority": 0,
        "removeDuplicates": "featureType",
        "removeDuplicatesDistance": 300,
        "repeatLabel":false,
        "repeatLabelDistance":0,
        "stackLabel": true,
        "stackAlignment": "dynamic",
        "stackRowLength": 20,
        "stackBreakPosition": "before",
        "symbol": {"type": "esriTS", "color": [255,0,0,255], "backgroundColor": null, "borderLineColor": null, "verticalAlignment": "middle", "horizontalAlignment": "center", "rightToLeft": false, "angle": 0, "xoffset": 0, "yoffset": 0, "font": {"family": "Arial", "size": 10, "style": "normal", "weight": "bold", "decoration": "none"}},
        }
        """
        //let labelDefinitionString = "{\r\n\"labelExpressionInfo\": {\r\n\"expression\": \"return $feature.都市名;\"},\r\n\"symbol\": {\r\n\"color\": [255,0,0,255],\r\n\"font\": {\"size\": 8, \"weight\": \"bold\"},\r\n\"type\": \"esriTS\"}\r\n}\r\n"
        
        guard let jsonData = labelDefinitionString.data(using: .utf8) else {
            throw NSError(domain: "cocoa-tests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create json data from label definition json string"])
        }
        //convert string data into JSON
        var JSON = try JSONSerialization.jsonObject(with: jsonData, options: JSONSerialization.ReadingOptions.mutableContainers)
        
        if var jsonDict = JSON as? Dictionary<String, Any> {
            jsonDict["symbol"] = try textSymbol.toJSON()
            JSON = jsonDict
        }
        
        //convert JSON into AGSLabelDefinition
        let labelDefinition = try AGSLabelDefinition.fromJSON(JSON)
        return labelDefinition as! AGSLabelDefinition
    }
}
