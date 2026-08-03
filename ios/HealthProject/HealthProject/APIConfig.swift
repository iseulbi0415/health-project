//
//  APIConfig.swift
//  HealthProject
//
//  API 서버 주소를 한 곳에 모아둠 — 예전엔 각 *APIService.swift 파일마다 baseURL을 따로
//  하드코딩해서, 시뮬레이터(localhost) ↔ 실기기(LAN IP/배포 주소) 전환 때마다 6곳을 일일이
//  고쳐야 했음. 실기기 카카오 로그인이 "Could not connect to the server"로 실패한 원인이
//  바로 이 localhost 하드코딩이었음(2026-08-03) — 여기 한 줄만 바꾸면 전체가 같이 바뀜
//

import Foundation

enum APIConfig {
    static let baseURL = "https://health-project-production-5204.up.railway.app"
}
