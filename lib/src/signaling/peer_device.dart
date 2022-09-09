/*
 * @Author: Beoyan
 * @Date: 2022-09-08 17:09:29
 * @LastEditTime: 2022-09-08 17:09:29
 * @LastEditors: Beoyan
 * @Description: 
 */
class PeerDevice {
  final String? flag;
  final String? name;
  final String? version;

  const PeerDevice({this.flag, this.name, this.version});

  PeerDevice.fromMap(Map data)
      : flag = data['flag'],
        name = data['name'],
        version = '${data['version']}';
}
