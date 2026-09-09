package io.nekohasekai.sagernet.fmt.wireguard

import moe.matsuri.nb4a.SingBoxOptions
import moe.matsuri.nb4a.utils.listByLineOrComma

fun genReservedList(anyStr: String): List<Int>? {
    val list = anyStr.listByLineOrComma()
    if (list.size == 3) {
        val ints = list.map {
            it.replace("[", "").replace("]", "").replace(" ", "").toIntOrNull()
        }
        if (ints.all { it != null }) return ints.map { it!! }
    }
    return null
}

fun buildSingBoxEndpointWireguardBean(bean: WireGuardBean): SingBoxOptions.Endpoint_WireGuardOptions {
    return SingBoxOptions.Endpoint_WireGuardOptions().apply {
        type = "wireguard"
        address = bean.localAddress.listByLineOrComma()
        private_key = bean.privateKey
        if (bean.mtu > 0) mtu = bean.mtu
        peers = listOf(SingBoxOptions.WireGuardEndpointPeer().apply {
            address = bean.serverAddress
            port = bean.serverPort
            public_key = bean.peerPublicKey
            if (bean.peerPreSharedKey.isNotBlank()) pre_shared_key = bean.peerPreSharedKey
            allowed_ips = listOf("0.0.0.0/0", "::/0")
            if (bean.reserved.isNotBlank()) genReservedList(bean.reserved)?.let { reserved = it }
        })
    }
}
