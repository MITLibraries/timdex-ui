// app/javascript/controllers/map_controller.js
import { Controller } from "@hotwired/stimulus"
// import L from 'leaflet'
export default class extends Controller {
  static values = {
    coords: Array,
    id: String
  }
  connect() {
    // Map logic goes here
    // console.log(this.identifier)
    // console.log(this.coordsValue)
    // console.log(this.idValue)

    var map = L.map(this.idValue);
    
    L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
      attribution: '&copy; <a href="http://www.openstreetmap.org/copyright">OpenStreetMap</a>'
    }).addTo(map);

    // create an orange rectangle
    L.rectangle(this.coordsValue, {color: "#ff7800", weight: 1}).addTo(map);

    // // zoom the map to the rectangle bounds
    map.fitBounds(this.coordsValue);
  }
}
