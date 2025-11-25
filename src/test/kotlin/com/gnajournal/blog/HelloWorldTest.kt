package com.gnajournal.blog

import io.kotest.core.spec.style.DescribeSpec
import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldContain
import io.ktor.client.request.*
import io.ktor.client.statement.*
import io.ktor.http.*
import io.ktor.server.testing.*

/**
 * Hello World 테스트 - Kotest + Ktor 테스트 예제
 */
class HelloWorldTest : DescribeSpec({

    describe("Hello World 테스트") {

        describe("기본 Assertion 테스트") {
            it("문자열이 일치해야 한다") {
                val greeting = "Hello, World!"
                greeting shouldBe "Hello, World!"
            }

            it("문자열이 특정 문자를 포함해야 한다") {
                val greeting = "Hello, Ktor!"
                greeting shouldContain "Ktor"
            }
        }

        describe("Ktor 라우트 테스트") {
            it("GET / 요청이 200 OK를 반환해야 한다") {
                testApplication {
                    application {
                        module()
                    }

                    val response = client.get("/")

                    response.status shouldBe HttpStatusCode.OK
                }
            }

            it("GET / 요청이 Hello World를 반환해야 한다") {
                testApplication {
                    application {
                        module()
                    }

                    val response = client.get("/")
                    val body = response.bodyAsText()

                    body shouldContain "Hello World"
                }
            }
        }
    }
})