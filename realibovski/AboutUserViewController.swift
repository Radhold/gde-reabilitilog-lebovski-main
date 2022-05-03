import Foundation
import UIKit

class AboutUserViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource, UITextFieldDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        switch pickerView.tag {
        case 1: return sexOptions.count
        case 2: return ageOptions.count
        case 3: return cogniOptions.count
        default: break
        }
        return 0
    }
    
    func pickerView( _ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        switch pickerView.tag {
        case 1: return sexOptions[row]
        case 2: return String(ageOptions[row])
        case 3: return cogniOptions[row]
        default: break
        }
        return nil
    }

    func pickerView( _ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        switch pickerView.tag {
        case 1: sex.text = sexOptions[row]
        case 2: age.text = String(ageOptions[row])
        case 3: cogni.text = cogniOptions[row]
        default: break
        }
    }

    let sexOptions = ["Мужской", "Женский"]
    let ageOptions = Array(14...100)
    let cogniOptions = ["Да", "Нет"]
    var pickers: [UIPickerView] = [UIPickerView(), UIPickerView(), UIPickerView()]
    @IBOutlet weak var sex: UITextField! {
        didSet{
            let picker = UIPickerView()
            
            picker.dataSource = self
            picker.delegate = self
            picker.tag = 1
            
            pickers[0] = picker
            sex.delegate = self
            sex.tag = 1
            sex.inputView = picker
        }
    }
    @IBOutlet weak var age: UITextField!{
        didSet{
            let picker = UIPickerView()
            
            picker.delegate = self
            picker.dataSource = self
            picker.tag = 2
            
            pickers[1] = picker
            age.tag = 2
            age.delegate = self
            age.inputView = picker
        }
    }
    @IBOutlet weak var cogni: UITextField!{
        didSet{
            let picker = UIPickerView()
            
            picker.delegate = self
            picker.dataSource = self
            picker.tag = 3
            
            
            cogni.inputView = picker
            pickers[2] = picker
            cogni.tag = 3
            cogni.delegate = self
        }
    }
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    @IBAction func action(_ sender: Any) {
        let vc = UIStoryboard(name: "Main", bundle: Bundle.main).instantiateViewController(withIdentifier: "navigationVC") as? UINavigationController
        UIApplication.shared.windows.first?.rootViewController = vc
        UIApplication.shared.windows.first?.makeKeyAndVisible()
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        pickerView(pickers[textField.tag - 1], didSelectRow: pickers[textField.tag - 1].selectedRow(inComponent: 0), inComponent: 0
        )
    }
    
}
