// jquery.payment script

createCryptogram = function() {
  var result = checkout.createCryptogramPacket();
  if (result.success) {
    cryptogram = result.packet
  }
};

$(function() {
  checkout = new cp.Checkout(
    "test_00000000000000001",
    document.getElementById("paymentSample"));
});
