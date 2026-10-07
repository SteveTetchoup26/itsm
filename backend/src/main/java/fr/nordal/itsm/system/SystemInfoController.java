package fr.nordal.itsm.system;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/system")
class SystemInfoController {

    private final SystemInfoService service;

    SystemInfoController(SystemInfoService service) {
        this.service = service;
    }

    @GetMapping("/info")
    SystemInfo info() {
        return service.info();
    }
}
